# Ansible Configuration para Restaurante-Carloncho

Automatización de configuración de instancias EC2 mediante Ansible, utilizando AWS Systems Manager (SSM) como conector.

## Estructura

```
ansible/
├── inventory/
│   └── aws_ec2.yml          # Inventario dinámico de AWS EC2
├── playbooks/
│   └── configure.yml        # Playbook principal
├── roles/
│   └── backend_setup/       # Rol para configurar backend Java
│       ├── tasks/
│       │   └── main.yml
│       └── templates/
│           ├── restaurante-crud.service.j2
│           └── logrotate.j2
└── README.md
```

## Requisitos

### En la máquina local (donde ejecutas Ansible)
- Python 3.9+
- Ansible 2.10+
- boto3 (para el plugin aws_ec2)
- AWS CLI configurado con credenciales

### En las instancias EC2
- AWS Systems Manager Agent (ya instalado en el user_data de EC2)
- IAM role con permisos de SSM

### Instalación

```bash
# Instalar Ansible
pip install ansible

# Instalar colecciones necesarias
ansible-galaxy collection install amazon.aws
ansible-galaxy collection install community.aws

# Instalar dependencias Python
pip install boto3 botocore
```

## Uso

### Descubrir instancias EC2

```bash
cd ansible

# Listar todos los hosts descubiertos
ansible-inventory -i inventory/aws_ec2.yml --graph

# Filtrar por grupo (ejemplo: solo instancias en prod)
ansible-inventory -i inventory/aws_ec2.yml --graph | grep tag_Environment_prod
```

### Ejecutar playbook de configuración

```bash
# Ejecutar contra todas las instancias CRUD
ansible-playbook playbooks/configure.yml \
  -i inventory/aws_ec2.yml \
  -u ubuntu \
  --extra-vars "java_version=21"

# Ejecutar contra un ambiente específico (prod)
ansible-playbook playbooks/configure.yml \
  -i inventory/aws_ec2.yml \
  -l tag_Environment_prod \
  -u ubuntu

# Ejecutar en modo "dry-run" (sin cambios)
ansible-playbook playbooks/configure.yml \
  -i inventory/aws_ec2.yml \
  -u ubuntu \
  --check

# Ejecutar con verbosidad
ansible-playbook playbooks/configure.yml \
  -i inventory/aws_ec2.yml \
  -u ubuntu \
  -vv
```

### Validar conectividad

```bash
# Ping a todas las instancias
ansible -i inventory/aws_ec2.yml tag_Role_crud -m ping

# Recopilar hechos de las instancias
ansible -i inventory/aws_ec2.yml tag_Role_crud -m setup | head -50
```

## Variables Importantes

### Inventario (aws_ec2.yml)
- `regions`: Regiones AWS a descubrir
- `filters`: Tags de EC2 para filtrar instancias
- `ansible_connection`: Tipo de conexión (aws_ssm)

### Playbook (configure.yml)
- `java_version`: Versión de Java a instalar (default: 21)
- `spring_boot_port`: Puerto de la aplicación Spring Boot (default: 8080)
- `app_user` / `app_group`: Usuario/grupo para la aplicación
- `app_home`: Directorio base de la aplicación

## Troubleshooting

### Error: "Failed to resolve credentials"
```bash
# Validar credenciales AWS
aws sts get-caller-identity

# Validar variables de entorno
env | grep AWS
```

### Error: "Unable to connect to AWS SSM"
```bash
# Verificar que la instancia EC2 tiene el role IAM correcto
# Verificar que Systems Manager Agent está corriendo en la EC2

# En la EC2:
sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service
```

### Error: "No hosts matched"
```bash
# Verificar que las instancias tienen los tags correctos
aws ec2 describe-instances \
  --region us-east-2 \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Environment`].Value|[0],Tags[?Key==`Role`].Value|[0]]' \
  --output table
```

## Ciclo Típico

1. **Terraform crea las instancias EC2** con tags (Environment, Role)
2. **EC2 instala Systems Manager Agent** en user_data
3. **Ansible descubre las instancias** vía plugin aws_ec2
4. **Ansible ejecuta playbooks** para instalar/configurar el stack Java
5. **Systemd cuida que la aplicación siga corriendo**

## Documentación Adicional

- [Ansible AWS EC2 Plugin](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)
- [Ansible AWS SSM Connection](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ssm_connection.html)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
