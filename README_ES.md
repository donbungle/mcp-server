# Entorno de Desarrollo MCP

Un entorno de desarrollo integral basado en Docker para construir y probar servidores del Protocolo de Contexto de Modelo (MCP).

## 🎯 Qué Incluye

**Servicios Principales:**
- **Servidor MCP Python** (Puerto 8000) - Implementación completa con depuración
- **Servidor MCP Node.js** (Puerto 3000) - Implementación alternativa 
- **PostgreSQL** (Puerto 5432) - Base de datos con datos de muestra
- **Redis** (Puerto 6379) - Capa de caché
- **Servidor de Archivos Nginx** (Puerto 8080) - Servicio de archivos estáticos con CORS

**Características de Desarrollo:**
- Recarga en caliente para Python y Node.js
- Soporte de depurador integrado (Python: 5678, Node.js: 9229)
- Registro y monitoreo integral
- Frameworks de pruebas preconfigurados
- Datos de muestra y esquemas
- Herramientas de calidad de código (linting, formato, verificación de tipos)

## 🚀 Inicio Rápido

1. **Configurar el entorno:**
```bash
# Hacer ejecutable el script de configuración y ejecutarlo
chmod +x setup.sh
./setup.sh
```

2. **Verificar que todo funciona:**
```bash
# Verificar estado de servicios
docker-compose ps

# Probar endpoints
curl http://localhost:8080/health  # Servidor de archivos
curl http://localhost:8000/health  # Servidor MCP Python  
curl http://localhost:3000/health  # Servidor MCP Node.js
```

3. **Comenzar a desarrollar:**
```bash
# Editar el servidor MCP Python
vim src/main.py

# Ver logs en tiempo real
docker-compose logs -f mcp-server

# Ejecutar pruebas
docker-compose exec mcp-server python -m pytest
```

## 🔧 Características Clave de los Servidores MCP

**Herramientas Disponibles:**
- `write_file` - Escribir contenido a archivos
- `execute_sql` - Ejecutar consultas de base de datos  
- `cache_set/get` - Operaciones de caché Redis
- `list_directory` - Navegar sistema de archivos
- `analyze_data` - Análisis básico de datos en archivos CSV

**Recursos:**
- Acceso al sistema de archivos del directorio `/data`
- Esquemas de tablas de base de datos y datos de muestra
- Archivos de configuración y documentación

**Ejemplo de Uso:**
```python
# El servidor Python proporciona herramientas para:
await mcp_server.call_tool("write_file", {
    "path": "analysis.txt", 
    "content": "Resultados de análisis de muestra"
})

await mcp_server.call_tool("execute_sql", {
    "query": "SELECT * FROM users WHERE department = $1",
    "parameters": ["Engineering"] 
})
```

## 🐛 Configuración de Depuración

**Python (VSCode):**
```json
{
  "name": "Python: Remote Attach",
  "type": "python", 
  "request": "attach",
  "connect": {"host": "localhost", "port": 5678},
  "pathMappings": [
    {"localRoot": "${workspaceFolder}/src", "remoteRoot": "/app/src"}
  ]
}
```

**Node.js (Chrome DevTools):**
- Abrir `chrome://inspect`
- Conectar a `localhost:9229`

## 📊 Monitoreo y Logs

```bash
# Ver todos los logs de servicios
docker-compose logs -f

# Monitorear servicio específico
docker-compose logs -f mcp-server

# Verificar uso de recursos
docker stats

# Operaciones de base de datos
docker-compose exec postgres psql -U mcp_user -d mcp_dev

# Operaciones Redis  
docker-compose exec redis redis-cli
```

## 🛠️ Flujo de Trabajo de Desarrollo

El entorno soporta ambos métodos de transporte:
- **stdio** (predeterminado) - Para integración directa del cliente MCP
- **HTTP/WebSocket** - Para desarrollo y pruebas basadas en web

Puedes cambiar fácilmente entre implementaciones o ejecutar ambas simultáneamente para comparación y pruebas.

## 🗂️ Estructura del Proyecto

```
mcp/
├── src/                    # Código fuente del servidor MCP Python
│   └── main.py            # Implementación principal del servidor Python
├── src-node/              # Código fuente del servidor MCP Node.js
│   └── server.js          # Implementación principal del servidor Node.js
├── db/                    # Scripts de inicialización de base de datos
│   ├── init.sql           # Esquemas y tablas
│   └── sample_data.sql    # Datos de muestra
├── data/                  # Archivos de datos (montados a contenedores)
├── static/                # Archivos estáticos servidos por Nginx
├── tests/                 # Suites de pruebas
├── .vscode/               # Configuración de depuración VSCode
├── docker-compose.yml     # Definiciones de servicios
├── python.Dockerfile      # Contenedor del servidor Python
├── node.Dockerfile        # Contenedor del servidor Node.js
├── nginx.conf             # Configuración de Nginx
├── setup.sh               # Script de configuración y administración
└── README.md              # Este archivo
```

## 🔧 Comandos de Administración

El script `setup.sh` proporciona administración conveniente:

```bash
./setup.sh setup     # Configuración inicial e inicio (predeterminado)
./setup.sh start     # Iniciar servicios
./setup.sh stop      # Detener servicios  
./setup.sh restart   # Reiniciar servicios
./setup.sh status    # Mostrar estado de servicios
./setup.sh logs      # Mostrar logs de servicios
./setup.sh clean     # Eliminar todo (con confirmación)
./setup.sh help      # Mostrar ayuda
```

## 🧪 Pruebas

Ambos servidores Python y Node.js incluyen suites de pruebas integrales:

```bash
# Ejecutar pruebas Python
docker-compose exec mcp-server python -m pytest tests/ -v

# Ejecutar pruebas Node.js  
docker-compose exec mcp-server-node npm test

# Ejecutar pruebas con cobertura
docker-compose exec mcp-server python -m pytest tests/ --cov=src
```

## 🔍 Esquema de Base de Datos

La base de datos PostgreSQL incluye varias tablas de muestra:
- `users` - Cuentas de usuario con departamentos y roles
- `products` - Catálogo de productos con categorías e inventario
- `orders` - Historial de pedidos con seguimiento de estado
- `order_items` - Elementos de línea de pedido
- `analytics_events` - Datos de seguimiento de eventos
- `app_config` - Configuración de aplicación

## 📡 Endpoints de API

**Servidor de Archivos (Puerto 8080):**
- `GET /health` - Verificación de salud
- `GET /data/` - Navegar directorio de datos
- `GET /static/` - Navegar archivos estáticos
- `GET /api/docs` - Documentación de API

**Servidor MCP Python (Puerto 8000):**
- `GET /health` - Verificación de salud
- Protocolo MCP vía transporte stdio

**Servidor MCP Node.js (Puerto 3000):**
- `GET /health` - Verificación de salud  
- Protocolo MCP vía transporte stdio

## 🚨 Solución de Problemas

**Servicios no iniciando:**
1. Verificar que Docker está corriendo: `docker info`
2. Verificar conflictos de puertos: `netstat -tulpn | grep :8000`
3. Ver logs de inicio: `docker-compose logs`

**Problemas de conexión de base de datos:**
```bash
# Probar conectividad de base de datos
docker-compose exec postgres pg_isready -U mcp_user

# Conectar a base de datos manualmente
docker-compose exec postgres psql -U mcp_user -d mcp_dev
```

**Problemas de conexión Redis:**
```bash
# Probar conectividad Redis
docker-compose exec redis redis-cli ping
```

**Depuración no funciona:**
- Asegurar que los puertos de depuración (5678, 9229) no están en uso
- Verificar configuración de firewall
- Verificar que la configuración de depuración VSCode coincida con la configuración del contenedor

## 🤝 Contribuir

1. Fork del repositorio
2. Hacer cambios en tu entorno
3. Probar exhaustivamente con las suites de pruebas proporcionadas
4. Enviar pull request

## 📄 Licencia

Este proyecto se proporciona tal como está para propósitos de desarrollo y pruebas.

---

¡Este entorno te proporciona una plataforma de desarrollo MCP completa con bases de datos reales, caché, sistemas de archivos y herramientas de depuración - perfecto para construir y probar servidores MCP listos para producción!