FROM nginx:alpine

# Crear usuario no privilegiado, configurar nginx y preparar archivos del frontend
RUN addgroup -S appgroup && adduser -S appuser -G appgroup && \
    sed -i 's|pid /var/run/nginx.pid;|pid /tmp/nginx.pid;|g' /etc/nginx/nginx.conf && \
    mkdir -p /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp && \
    printf 'server {\n\
    listen 8080;\n\
\n\
    location / {\n\
        root /usr/share/nginx/html;\n\
        index index.html;\n\
    }\n\
\n\
    location /actuator/health {\n\
        add_header Content-Type application/json;\n\
        return 200 '"'"'{"status":"UP"}'"'"';\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf && \
    printf '<!DOCTYPE html>\n\
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
</html>' > /usr/share/nginx/html/index.html && \
    chown -R appuser:appgroup /var/cache/nginx /var/run /tmp /usr/share/nginx/html /etc/nginx/conf.d

USER appuser

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]