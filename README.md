# NexusAI: Hybrid Intelligence Gateway

**NexusAI** es un proxy ligero que unifica la potencia de **Google Gemini** (Nube) y la privacidad de **Ollama/Mistral** (Local) bajo una única interfaz compatible con el protocolo OpenAI. Diseñado para integrarse nativamente con **Open WebUI**.

![Docker](https://img.shields.io/badge/Docker-Enabled-blue?logo=docker) ![Python](https://img.shields.io/badge/FastAPI-Powered-009688?logo=fastapi)

## Despliegue Rápido

**1. Clonar y entrar:**
```bash
git clone [https://github.com/leerot/IA-Local.git](https://github.com/leerot/IA-Local.git)
cd IA-Local
```

**2. Configurar credenciales:** Crea un archivo api/.env y añade tu llave de Google:
```Bash
echo "GEMINI_API_KEY=tu_api_key_aqui" > api/.env
```

**3. Iniciar sistema:** Usa el script de control automatizado:
```bash
chmod +x nexusai.sh
sudo ./nexusai.sh
```
> Selecciona la opción 1 para construir y desplegar.
