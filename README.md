# Proyecto Restaurante Agile
El presente proyecto propone el desarrollo de un sistema web para apoyar la gestión del restaurante “Carloncho”. Actualmente, los pedidos, ventas e inventario todavía se hacen con lapicero y papel, causando demoras en la atención, error en los pedidos y poco control sobre lo que ocurre en el día a día.
La solución plantea reunir en un sistema las principales actividades del restaurante, como el registro de pedidos, la administración de productos, el control de mesas, la revisión del inventario y la consulta de ventas. Con esto, el personal podrá trabajar con información más ordenada, evitando confusiones y errores.

Estudiantes a cargo del proyecto:
- Nieve Viera, Daniela
- Rabanal Ocampo, Estalin
- Ruiz Tulumba, Bryan

Diagrama propuesto:
<img width="1600" height="609" alt="diagrama-iac" src="https://github.com/user-attachments/assets/ffc6bd45-c6e6-4f29-88eb-0b9cf6e1e693" />

---

## Guía de Despliegue de Infraestructura del proyecto del restuarante Carloncho  

El proyecto utiliza **Terraform** para levantar toda la infraestructura necesaria en AWS (Bases de datos, S3, CloudFront, Lambda, API Gateway, etc.) y **GitHub Actions** para automatizar el proceso.

### Opción 1: Despliegue Automático

Gracias a la integración con GitHub Actions, el despliegue es completamente automatizado de principio a fin.

1. **Haz un push a tu repositorio:** Cualquier cambio en el código o configuración disparará un proceso.
2. **Workflow `Terraform Apply`:**
   - Si entras a la pestaña **Actions** en GitHub, podrás ejecutar manualmente el workflow `Terraform Apply`.
   - Este proceso se encargará de crear toda la infraestructura.
   - Al finalizar, automáticamente **descargará el submódulo de frontend**, renombrará `login.html` a `index.html` y **subirá los archivos a S3** para que la página sea visible inmediatamente en CloudFront.
3. **Workflow `Terraform Destroy`:**
   - Si necesitas apagar todo para evitar costos, ejecuta el workflow `Terraform Destroy` desde la pestaña Actions y todo se eliminará limpiamente de AWS.

### Opción 2: Despliegue Manual (Local)

Si prefieres levantar el proyecto desde tu propia computadora (terminal):

#### Prerrequisitos
- Tener [Terraform](https://developer.hashicorp.com/terraform/install) instalado (`>= 1.7.0`).
- Tener el [AWS CLI](https://aws.amazon.com/es/cli/) instalado.
- Haber configurado tus credenciales de AWS ejecutando:
  ```bash
  aws configure
  ```

#### Pasos para desplegar

1. **Descargar los submódulos (Frontend, Backend, etc):**
   ```bash
   git submodule update --init --recursive
   ```

2. **Inicializar y aplicar Terraform:**
   ```bash
   cd iac
   terraform init
   terraform workspace list
   terraform workspace new prod
   terraform workspace show (para verificar que te encuentras en el entorno prod)
   terraform plan
   terraform apply -auto-approve
   ```

3. **Subir el código del Frontend a S3:**
   Terraform crea los "edificios vacíos", por lo que debes subir tu código web al bucket de S3 recién creado.
   ```bash
   # Renombrar login.html a index.html para que CloudFront lo entienda
   mv ../frontend/frontend/login.html ../frontend/frontend/index.html
   
   # Sincronizar los archivos al bucket usando encriptación por defecto
   aws s3 sync ../frontend/frontend s3://restaurante-carloncho-frontend-prod --sse AES256
   ```

4. **Verificar:**
   En los *Outputs* del comando `terraform apply`, busca la URL que dice `cloudfront_domain_name`. Pégala en tu navegador y verás tu sistema funcionando.

#### Pasos para destruir (Apagar el sistema)

Para eliminar toda la infraestructura y asegurar que AWS no te cobre un centavo más:

```bash
cd iac
terraform destroy -auto-approve
```
>[link de grafana](https://redcroissant1739.grafana.net/d/inpr8pj/restaurante-observabilidad-aws?orgId=1&from=now-7d&to=now&timezone=browser)
> **Nota:** Terraform limpiará automáticamente los buckets de S3 sin importar si tienen archivos adentro, ya que están configurados con la opción `force_destroy = true`.
>[link de sonarqube](https://sonarcloud.io/project/overview?id=Estalin7_proyecto_infra)
> GRACIAS
