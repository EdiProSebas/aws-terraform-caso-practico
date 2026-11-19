# Infraestructura segura en AWS con Terraform

Caso práctico para Ingeniero Cloud AWS 2026 (DeUna).

![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A51.10-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-us--east--2-FF9900?logo=amazonaws&logoColor=white)
![Aurora PostgreSQL](https://img.shields.io/badge/Aurora%20PostgreSQL-16.15-336791?logo=postgresql&logoColor=white)

## Resumen

Este repositorio aprovisiona con Terraform la base de una plataforma de datos financiera en AWS: una llave KMS gestionada por el cliente, un bucket S3 cifrado, un clúster Aurora PostgreSQL y el control de acceso a su secreto de credenciales.

La solución se organiza en módulos pequeños y reutilizables, y sigue tres principios:

- **Mínimo privilegio** en las políticas de KMS, S3 y Secrets Manager.
- **Cifrado en reposo y en tránsito** para todos los datos.
- **Cambios revisables**: ningún recurso se crea sin revisar antes el plan.

## Respuestas del caso práctico

Las respuestas a las cuatro tareas del caso práctico están en [docs/respuestas-caso-practico.md](docs/respuestas-caso-practico.md). Cubren monitoreo de ECS, costeo por tipo de transacción, Terraform y gestión de incidentes en producción.

## Estado del proyecto

| Verificación | Resultado |
|---|---|
| `terraform validate` (root y bootstrap) | Correcto |
| `terraform plan` | 18 recursos por crear, 0 cambios, 0 destrucciones |
| `terraform apply` | Pendiente. No hay recursos desplegados |
| Estado remoto (`bootstrap`) | Definido, pendiente de aplicar |
| Análisis estático (Checkov o Trivy) | Pendiente |

## Arquitectura

| Componente | Descripción | Controles principales |
|---|---|---|
| KMS | Llave simétrica compartida por los demás servicios | Rotación automática, política explícita, alias `alias/cloud-practice-dev` |
| S3 | Almacenamiento de datos financieros | Cifrado con KMS, versionado, bloqueo de acceso público, política de bucket, lifecycle |
| Aurora PostgreSQL | Base de datos relacional | Cifrado con KMS, subredes privadas en dos zonas de disponibilidad, Security Group dedicado, backups, monitoreo |
| Secrets Manager | Credenciales del usuario administrador `pgadmin` | Cifrado con KMS, rotación gestionada por RDS, resource policy restrictiva |

### KMS

- Llave `SYMMETRIC_DEFAULT` con rotación habilitada y ventana de eliminación de 30 días.
- La política de la llave define tres sentencias:
  1. La cuenta raíz conserva la administración de la llave.
  2. El uso criptográfico solo se permite a través de S3, RDS y Secrets Manager en `us-east-2`, y únicamente para principales de la misma cuenta (`kms:ViaService` y `kms:CallerAccount`).
  3. Los grants solo se permiten para recursos de AWS (`kms:GrantIsForAWSResource`).

### Almacenamiento en S3

- Cifrado por defecto con la llave KMS del proyecto y *bucket key* habilitada.
- Versionado habilitado y bloqueo completo de acceso público.
- La política del bucket deniega:
  - Cualquier acceso sin TLS (`aws:SecureTransport`).
  - Subidas sin cifrado KMS o con otro algoritmo.
  - Subidas cifradas con una llave KMS distinta a la del proyecto.
- Reglas de lifecycle:

| Regla | Acción |
|---|---|
| `abort-incomplete-multipart-uploads` | Aborta cargas multipart incompletas a los 7 días |
| `expire-noncurrent-versions` | Expira versiones no actuales a los 90 días |
| `transition-to-standard-ia` | Transiciona objetos a `STANDARD_IA` a los 30 días |

Los plazos son valores de partida y deben ajustarse a la política de retención de la organización.

### Aurora PostgreSQL

- Motor `aurora-postgresql` 16.15, instancia `db.t4g.medium`, base de datos `appdb`, usuario administrador `pgadmin`.
- Almacenamiento cifrado con KMS e instancia sin acceso público (`publicly_accessible = false`).
- VPC propia (`10.20.0.0/16`) con dos subredes privadas en `us-east-2a` y `us-east-2b`.
- Backups automáticos con 7 días de retención y ventana de 07:00 a 08:00 UTC.
- Observabilidad: exportación de logs de PostgreSQL a CloudWatch, Performance Insights y monitoreo mejorado cada 60 segundos.

### Gestión de credenciales

- La contraseña de `pgadmin` la genera y administra Aurora (`manage_master_user_password`) y se almacena en Secrets Manager cifrada con KMS. No hay contraseñas en el código ni en el estado de Terraform.
- La rotación la realiza el propio servicio, por lo que no se requiere una función Lambda de rotación.
- El módulo `secret-access` añade una resource policy que deniega `secretsmanager:GetSecretValue` a cualquier principal que no figure en la lista permitida. Los servicios de AWS se excluyen del `Deny` mediante `aws:PrincipalIsAWSService`, para no interferir con la rotación.

## Estructura del repositorio

```text
.
├── docs/                      # Respuestas a las cuatro tareas del caso práctico
├── README.md
└── infra/
    ├── bootstrap/             # Bucket S3 para el estado remoto
    ├── modules/
    │   ├── kms/               # Llave KMS y su política
    │   ├── financial-storage/ # Bucket S3, cifrado, lifecycle y política
    │   ├── database/          # VPC, subredes, Security Group, Aurora y monitoreo
    │   └── secret-access/     # Resource policy del secreto
    └── root/
        ├── main.tf            # Composición de los módulos
        ├── variables.tf
        ├── locals.tf          # Etiquetas comunes
        ├── provider.tf
        ├── versions.tf
        ├── backend.tf.disabled  # Backend S3, deshabilitado hasta aplicar bootstrap
        └── terraform.tfvars.example

infra/
├── bootstrap/             # Bucket S3 para el estado remoto
├── modules/
│   ├── kms/               # Llave KMS y su política
│   ├── financial-storage/ # Bucket S3, cifrado, lifecycle y política
│   ├── database/          # VPC, subredes, Security Group, Aurora y monitoreo
│   └── secret-access/     # Resource policy del secreto
└── root/                  # Composición de los módulos y configuración del backend
```

El provider `hashicorp/aws` se declara con la restricción `>= 5.0.0, < 7.0.0` en `root`, `bootstrap` y los módulos `database` y `secret-access`. El lock file fija la versión 6.73.0.

## Uso

**Requisitos:** Terraform 1.10 o superior (necesario para el bloqueo nativo en S3), AWS CLI configurado y permisos suficientes en la cuenta.

```powershell
cd infra\root
terraform init
terraform validate
terraform plan -out=tfplan
```

Tras revisar el plan, el despliegue se ejecuta de forma explícita:

```powershell
terraform apply "tfplan"
```

Los valores sensibles (`*.tfvars`), el estado local y los planes guardados están excluidos del control de versiones mediante `.gitignore`.

## Estado remoto

El estado se almacena en un bucket S3 creado desde `infra/bootstrap`, con las siguientes características:

- Versionado, cifrado `AES256`, bloqueo de acceso público y TLS obligatorio.
- `prevent_destroy` para evitar su eliminación accidental.
- Bloqueo de estado nativo de S3 (`use_lockfile = true`), sin necesidad de DynamoDB.
- Cifrado `AES256` en lugar de la llave KMS del proyecto, para que el estado no dependa de un recurso que él mismo administra.

Secuencia de adopción:

```powershell
terraform -chdir=../bootstrap init
terraform -chdir=../bootstrap apply

# Con backend.tf presente en infra/root:
terraform init -migrate-state
```

El bucket sigue el patrón `cloud-practice-tfstate-<ACCOUNT_ID>`.

## Seguridad y calidad

Controles aplicados:

- Validación de sintaxis y configuración con `terraform validate` en `root` y `bootstrap`.
- Revisión manual del plan contra los requisitos: cifrado, acceso público, políticas, backups y etiquetado.
- Exclusión de secretos, estado y credenciales del repositorio.

Controles recomendados para un pipeline de CI (aún no implementados):

- Análisis estático con [Checkov](https://www.checkov.io/) o [Trivy](https://trivy.dev/).
- `terraform fmt -check` para uniformidad de estilo.
- `terraform plan` en cada pull request, con aprobación manual previa al `apply`.

## Consideraciones y limitaciones

- **Costos:** Aurora, Performance Insights y el monitoreo mejorado generan cargos por hora, y la llave KMS cobra por mes. En un entorno de pruebas conviene ejecutar `terraform destroy` al terminar.
- **Entorno de pruebas:** el clúster usa `deletion_protection = false` y `skip_final_snapshot = true`. Esta configuración no es adecuada para producción.
- **Permisos de KMS:** el plan no valida los permisos efectivos. Si el `apply` falla por acceso a la llave, el primer punto a revisar es su política.
- **Política del secreto:** actualmente solo permite al usuario `terraform-practice` y a la cuenta raíz. Falta incorporar el rol de las tareas ECS.

## Próximos pasos

1. Aplicar `bootstrap` y migrar el estado a S3.
2. Integrar los Security Groups y el rol IAM de las tareas ECS.
3. Incorporar Checkov o Trivy al pipeline y resolver o justificar los hallazgos.
4. Habilitar `deletion_protection` y snapshot final para producción.
