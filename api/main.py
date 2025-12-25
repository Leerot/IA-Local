from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import requests
import google.generativeai as genai
import os
from dotenv import load_dotenv
import logging
from fastapi import Body
from fastapi.middleware.cors import CORSMiddleware  # ### NUEVO: Importar CORS

# Configuración de Logs para debugear en Parrot OS
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

app = FastAPI(title="IA Hybrid API - leerot Solutions")

# ### NUEVO: Configuración de CORS (Permisos de acceso)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite conexiones desde cualquier IP (Open WebUI)
    allow_credentials=True,
    allow_methods=["*"],  # Permite todos los métodos (GET, POST, OPTIONS)
    allow_headers=["*"],  # Permite todos los headers
)

# --- CONFIGURACIÓN ---
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://ollama:11434/api/generate")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
else:
    logger.warning("GEMINI_API_KEY no detectada. Solo funcionará el modo local.")

# Esquema de datos para validar la entrada
class ChatRequest(BaseModel):
    prompt: str
    provider: str = "ollama"  # ollama o gemini
    model_name: str = None    # Opcional: para cambiar entre mistral o deepseek-r1

@app.post("/chat")
async def chat(request: ChatRequest = Body(...)):
    # --- PROVEEDOR: GEMINI (Análisis Lógico Pesado) ---
    if request.provider == "gemini":
        if not GEMINI_API_KEY:
            raise HTTPException(status_code=503, detail="Servicio de Gemini no configurado.")
        
        try:
            # Usamos gemini-1.5-pro para máxima capacidad de razonamiento
            model = genai.GenerativeModel('gemini-flash-latest')
            response = await model.generate_content_async(request.prompt)
            return {
                "response": response.text.strip(),
                "source": "Gemini 1.5 Pro (Cloud)"
            }
        except Exception as e:
            logger.error(f"Fallo en Gemini: {e}")
            raise HTTPException(status_code=500, detail="Error procesando con IA en la nube.")

    # --- PROVEEDOR: OLLAMA (Privacidad Local / Pentesting) ---
    else:
        # Si no especificas modelo, usamos tu mistral optimizado
        selected_model = request.model_name or "mistral:7b-instruct-v0.3-q4_K_M"
        
        payload = {
            "model": selected_model,
            "prompt": request.prompt,
            "stream": False,
            "options": {"num_predict": 250} # Un poco más de margen para respuestas útiles
        }

        try:
            # Timeout de 60s por si el modelo está cargando en RAM
            r = requests.post(OLLAMA_URL, json=payload, timeout=60)
            r.raise_for_status()
            data = r.json()
            
            clean_response = data.get("response", "").replace("**", "").strip()
            
            return {
                "response": clean_response,
                "source": f"{selected_model} (Local Server)"
            }
        except requests.exceptions.Timeout:
            raise HTTPException(status_code=504, detail="Ollama tardó demasiado en responder.")
        except Exception as e:
            logger.error(f"Fallo en Ollama: {e}")
            raise HTTPException(status_code=500, detail="Error en el servidor local de IA.")

# Endpoint de salud para Docker
@app.get("/health")
def health_check():
    return {"status": "ready", "engine": "hybrid"}