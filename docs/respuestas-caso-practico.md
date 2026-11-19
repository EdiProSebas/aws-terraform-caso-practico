Respuestas caso practico - Ingeniero Cloud AWS
DeUna / Devsu

Las escribi en orden, una detras de otra, como las fui pensando. No use tablas
porque me parece que se leen peor cuando alguien las revisa rapido.


TAREA 1 - Monitoreo del escalamiento en ECS

La idea central es no depender de CloudWatch como herramienta de observabilidad,
porque en DeUna la plataforma principal es externa y lo que hace es ingerir los
logs. CloudWatch queda entonces como fuente de metricas y como motor de reglas,
nada mas.

Deteccion. El evento que me interesa no es "subio la CPU", es "el servicio ya no
puede crecer mas". Eso se ve comparando RunningTaskCount contra el maximo
configurado del servicio. Como cada servicio tiene su propio maximo, no sirve una
alarma con umbral fijo. Lo que hago es guardar el maximo como parametro en SSM
Parameter Store por servicio y resolverlo en la alarma con metric math, o mas
simple todavia, dejar que el propio servicio ECS exponga el limite via tag y
construir la alarma por servicio desde Terraform, que al final es un for_each
sobre la lista de servicios. Con eso la condicion queda: RunningTaskCount mayor o
igual al maximo, sostenido 3 datapoints de 1 minuto. El "sostenido" importa, si
no cualquier pico de un minuto dispara.

Uso tambien Application Auto Scaling para leer la actividad de escalamiento, por
si quiero distinguir "llego al maximo y se quedo" de "llego al maximo y bajo".
El primero es saturacion real, el segundo es un pico que ya paso.

Integracion con la plataforma externa. El camino es EventBridge hacia una Lambda
enriquecida y de ahi al endpoint de la plataforma. La Lambda es la que arma el
payload, porque el evento crudo de CloudWatch trae muy poco contexto y el que
esta de guardia a las 3 AM no quiere adivinar. Despues de la Lambda uso API
Destination con un connection de Secrets Manager para la credencial, asi no hay
que meter un webhook con token en el codigo. La Lambda tambien escribe el evento
en el log group que ya ingesta la plataforma, para que quede en la misma linea de
tiempo que el resto de la telemetria del servicio.

Contenido de la alerta. Servicio y cluster, tareas actuales contra maximo
(10/10), desired count, CPU y memoria promedio del service, latencia p99 del
target group, cantidad de requests 5xx en la ventana, version o task definition
revision desplegada, hora del ultimo deploy, y el link al runbook. Agrego tambien
una linea de "que revisar primero" con tres pasos concretos, porque en la
practica eso es lo que se usa.

Ruido. Este es el punto donde mas se falla. Tres cosas: primero, una alarma
compuesta por servicio que solo notifica si la saturacion coincide con latencia
alta o con errores, asi no molesta cuando el servicio esta al maximo pero
respondiendo bien; segundo, deduplicacion por servicio con una ventana de
silenciamiento de 30 minutos, para que no lleguen 40 alertas iguales; tercero,
supresion durante ventanas de despliegue, porque un deploy normal tambien sube
tareas. Y separo severidades: saturacion sola es warning, saturacion con p99
arriba del SLO es critical y va a la guardia.

Dashboard. Una fila por servicio con tareas usadas sobre maximo, porcentaje de
headroom, minutos al maximo en las ultimas 24 horas, p99 y errores. Arriba una
tabla de "los que estan al limite ahora" ordenada por headroom. La metrica que
mas sirve para planificar no es la saturacion, es el tiempo acumulado al maximo
por semana, porque ahi se ve que servicio necesita que le suban el techo.


TAREA 2 - Costeo por tipo de transaccion

Aclaro algo desde el principio porque cambia todo el diseno: no se puede etiquetar
una transaccion individual en AWS. El tag se aplica al recurso, y los recursos son
compartidos. Entonces lo que se hace es repartir, no etiquetar por request.

Etiquetado y propagacion. El tipo de transaccion viaja en el header de la peticion
y se propaga como campo estructurado en el log de cada salto (API Gateway, Lambda,
SQS). En los recursos que si soportan tags pongo las dimensiones estables:
aplicacion, ambiente, dominio, owner. El tipo de transaccion no va como tag de
recurso porque cambiaria por request; va como dimension en los logs y en las
metricas de negocio.

Servicios compartidos. Para cada uno uso un driver. Lambda se reparte por
GB-segundo y por invocaciones, API Gateway por requests, SQS por mensajes y por
tiempo de retencion, Aurora por ACU-hora y por conexiones o por tiempo de
ejecucion de query, S3 por GB-mes y por requests. El driver se saca de CloudWatch
o de los logs, se agrega por tipo de transaccion y se aplica como proporcion sobre
el costo total del servicio en el periodo. Un ejemplo con numeros redondos: si
Aurora costo 1000 USD en el mes y el 70 por ciento de los ACU-hora vino de flujos
monetarios, se le asignan 700 a monetario y 300 a no monetario. Es aproximado y
asi hay que presentarlo, como costo atribuido, no como costo exacto.

Herramientas. Cost and Usage Report en formato Parquet, Athena para consultar,
Glue o Lambda para el calculo, QuickSight para la vista. Para los servicios con
componente compartido de computo conviene activar el split cost allocation data
del CUR, que ya trae el reparto de ECS y EKS por pod o por tarea y ahorra bastante
trabajo manual.

Automatizacion. El CUR cae en S3 todos los dias, un evento de S3 dispara el
calculo, se escribe una tabla de resultados particionada por mes y por tipo, y
QuickSight lee de ahi. El calculo es idempotente por dia, asi se puede reprocesar
sin duplicar.

Presentacion. A producto le muestro costo por cada 1000 transacciones y su
tendencia, que es la unidad que entienden. A finanzas le muestro el total por
dominio y la variacion contra el mes anterior con el driver que la explica. Y una
hoja aparte con el porcentaje de costo no atribuido, porque si ese numero crece
es que falta cobertura de tags y eso hay que verlo.


TAREA 3 - Terraform

La estructura quedo en tres capas: bootstrap para el bucket de estado y la tabla
de locks, modules con un modulo por dominio (kms, financial-storage, database,
secret-access) y root que los compone. La razon de separar bootstrap es que el
estado remoto no puede estar en el mismo estado que administra, es el problema del
huevo y la gallina.

Estado remoto. Bucket S3 versionado, encriptado con SSE-KMS, con bloqueo de
acceso publico y policy que niega HTTP sin TLS. Lock por tabla DynamoDB con
PayPerRequest. El backend esta en backend.tf.disabled a proposito, para que el
repo se pueda clonar y validar sin credenciales; se activa renombrando el archivo
y corriendo init con migrate-state. Todavia no lo active porque el apply lo tengo
que autorizar yo, no lo hago de oficio.

Recursos. Son 18 en el plan. KMS con rotacion anual, key policy con least
privilege y separacion de roles de administracion y de uso. S3 con las cuatro
reglas de lifecycle (abortar multipart, expirar versiones no actuales, transicion
a Standard-IA) y bucket policy que niega transporte inseguro, algoritmos distintos
de la llave y llaves distintas de la esperada. Aurora PostgreSQL en subredes
privadas, con security group que solo acepta 5432 desde el SG de las tareas,
backups con retencion, Performance Insights y enhanced monitoring con su rol de
IAM. Secrets Manager con la credencial de pgadmin, encriptado con la misma llave,
rotacion por Lambda y resource policy que niega GetSecretValue a cualquier
principal fuera de la lista, excluyendo los servicios de AWS con
aws:PrincipalIsAWSService para no romper la rotacion.

Validacion antes del apply. terraform fmt y validate en cada modulo, tflint para
lo especifico de AWS, checkov o trivy para el escaneo de seguridad, infracost para
ver el delta de costo del plan, y revision del plan guardado en archivo. El plan
lo leo entero, no solo el resumen, porque los cambios de policy son los que se
esconden.

Costo. La llave KMS y el secreto son costo fijo bajo. Lo que mueve la aguja es
Aurora, entonces la instancia minima y el auto pause se eligen por ahi, y las
reglas de lifecycle de S3 estan para que el bucket no crezca sin control.


TAREA 4 - Incidente en produccion

2:47, payments-processor en 10/10 y p99 arriba de 4 segundos. Lo primero no es
tocar nada, es abrir el canal y dejar escrito que alguien lo tomo. Despues
confirmo que la alerta es real y no un artefacto de metrica, mirando el dashboard
del servicio.

Diagnostico en orden. Primero capacidad: si esta en 10/10 y la CPU esta alta, es
falta de techo. Si esta en 10/10 y la CPU esta baja, no es capacidad, es que las
tareas estan esperando algo, y ahi el sospechoso es la base o una dependencia.
Segundo base de datos: ACU actual contra maximo, conexiones, latencia de query,
locks, CPU del writer. Tercero dependencia externa: latencia y tasa de error del
endpoint, y si hay timeouts en cascada. Cuarto, el ultimo cambio: si hubo deploy
en las dos horas previas, eso sube mucho en la lista. El orden importa porque
cada paso descarta una hipotesis y evita el clasico de escalar cuando el problema
era la base.

Mitigacion sin downtime. Subir el maximo de tareas es lo primero y es reversible,
pero solo sirve si el cuello es CPU. Si el cuello es la base, subir tareas empeora
todo porque le mete mas conexiones. En ese caso lo que hago es bajar el trafico no
critico, activar el circuit breaker hacia la dependencia que falla y, si el
problema vino con un deploy, hacer rollback a la revision anterior. Todo con
rolling update y health checks, sin reiniciar el servicio entero.

Comunicacion. Al equipo tecnico, en el canal del incidente, con lo que se sabe y
lo que se esta probando, cada 15 minutos. A producto, cada 30, en terminos de
impacto: que transacciones estan lentas y desde cuando. A C-Level, una sola vez
cuando hay mitigacion o cuando pasa de 30 minutos, con impacto, accion y hora
estimada, sin detalle tecnico.

Postmortem. Linea de tiempo, impacto medido en transacciones afectadas y minutos,
causa raiz, que funciono y que no, y acciones con owner y fecha. Sin culpables
nominales, eso solo hace que la gente deje de reportar. Y una accion concreta que
casi siempre sale de estos casos: revisar si el maximo de tareas del servicio
tiene sentido contra su trafico real, porque un 10/10 a las 2:47 suele ser un
techo mal dimensionado mas que un pico.
