FROM nginx:alpine

# Configurar nginx para escuchar en puerto 8080 (requerido por ECS task definition)
RUN sed -i 's/listen\s*80;/listen 8080;/g' /etc/nginx/conf.d/default.conf && \
    sed -i 's/listen\s*\[::\]:80/listen [::]:8080/g' /etc/nginx/conf.d/default.conf

# Pagina simple para comprobar que ECS + VPC Endpoints funcionan
RUN printf '<!DOCTYPE html>\n\
<html lang="es">\n\
<head>\n\
  <meta charset="UTF-8">\n\
  <title>Restaurante Carloncho - Backend OK</title>\n\
  <style>\n\
    body{font-family:sans-serif;background:#0f172a;color:#f8fafc;\n\
         display:flex;align-items:center;justify-content:center;\n\
         height:100vh;margin:0;text-align:center;}\n\
    h1{font-size:2.5rem;color:#38bdf8;}\n\
    p{color:#94a3b8;}\n\
    .badge{display:inline-block;background:#22c55e;color:#fff;\n\
           padding:4px 14px;border-radius:999px;font-size:.85rem;}\n\
  </style>\n\
</head>\n\
<body>\n\
  <div>\n\
    <h1>Restaurante Carloncho</h1>\n\
    <p>Backend corriendo en <strong>Amazon ECS Fargate</strong></p>\n\
    <span class="badge">Hello World - prod :8080</span>\n\
  </div>\n\
</body>\n\
</html>' > /usr/share/nginx/html/index.html

# Health check para el ALB (ruta /actuator/health configurada en prod.auto.tfvars)
RUN printf 'server {\n\
    listen 8080;\n\
    location / {\n\
        root /usr/share/nginx/html;\n\
        index index.html;\n\
    }\n\
    location /actuator/health {\n\
        return 200 '"'"'{"status":"UP"}'"'"';\n\
        add_header Content-Type application/json;\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf

# Ajustar permisos para que nginx (uid 101) pueda escribir pid y cache
RUN chown -R nginx:nginx /var/cache/nginx /var/run /var/log/nginx && \
    chmod -R 755 /var/cache/nginx /var/run /var/log/nginx

# Ejecutar como usuario no-root para reducir la superficie de ataque
USER nginx

EXPOSE 8080
