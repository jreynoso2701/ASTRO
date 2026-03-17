# ── Etapa 1: Build Flutter Web ──
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copiar todo el proyecto Flutter
COPY astro_app/ .

# Obtener dependencias y compilar web
RUN flutter pub get
RUN flutter build web --release --base-href "/"

# ── Etapa 2: Servir con Nginx ──
FROM nginx:alpine

# Copiar build de Flutter al directorio de Nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Configuración Nginx para SPA (redirige todas las rutas a index.html)
COPY nginx.conf /etc/nginx/templates/default.conf.template

# Railway inyecta PORT como variable de entorno (8080 por defecto)
ENV PORT=8080
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
