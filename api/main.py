from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import requests
import google.generativeai as genai
import os
from dotenv import load_dotenv
import logging
import time

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

app = FastAPI(title="Leerot - Hybrid NexusAI")

# --- CORS (OBLIGATORIO PARA OPEN WEBUI) ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- CONFIGURACIÓN ---
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://ollama:11434/api/generate")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")

if GEMINI_API_KEY:
    # Usamos el alias estable que ya te funcionó
    genai.configure(api_key=GEMINI_API_KEY)
else:
    logger.warning("GEMINI_API_KEY no detectada.")

# --- ESTRUCTURA OPENAI (Lo que Open WebUI envía) ---
class Message(BaseModel):
    role: str
    content: str

class ChatCompletionRequest(BaseModel):
    model: str
    messages: list[Message]
    stream: bool = False

# --- RUTAS QUE OPEN WEBUI BUSCA ---

@app.get("/v1/models")
def list_models():
    # Esto hace que aparezcan en tu lista desplegable
    return {
        "object": "list",
        "data": [
            {"id": "leerot-gemini", "object": "model", "owned_by": "leerot", "name": "Gemini Cloud"},
            {"id": "xiaomi-openrouter", "object": "model", "owned_by": "nexus", "name": "Xiaomi MiMo (OpenRouter)"},
            {"id": "leerot-mistral", "object": "model", "owned_by": "leerot", "name": "Mistral Local"}
        ]
    }

@app.post("/v1/chat/completions")
async def chat_completions(request: ChatCompletionRequest):
    # Para tomar el último mensaje del chat
    last_message = request.messages[-1].content
    model_used = request.model
    response_text = ""

    try:
        if "gemini" in model_used:
            # Lógica de Gemini
            model = genai.GenerativeModel('gemini-flash-latest') # Aqui especificas el modelo AI
            gemini_response = await model.generate_content_async(last_message)
            response_text = gemini_response.text
        
        elif "openrouter" in model_used:
            if not OPENROUTER_API_KEY:
                raise ValueError("OPENROUTER_API_KEY no configurada")
            
            headers = {
                "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
                "HTTP-Referer": "http://localhost:3000",
            }
            
            payload = {
                "model": "xiaomi/mimo-v2-flash:free",  # Aqui especificas el modelo AI
                "messages": [{"role": "user", "content": last_message}]
            }
            
            # 1. Petición
            r = requests.post("https://openrouter.ai/api/v1/chat/completions", headers=headers, json=payload, timeout=45)
            
            # 2. Convertir respuesta a JSON
            try:
                data = r.json()
            except:
                logger.error(f"OpenRouter no devolvió JSON. Status: {r.status_code}, Texto: {r.text}")
                raise HTTPException(status_code=500, detail="Error de formato en OpenRouter")

            # 3. VERIFICACIÓN DE ERROR
            if 'error' in data:
                error_msg = data['error'].get('message', 'Error desconocido')
                logger.error(f"X OPENROUTER ERROR: {data}") # Esto saldrá en tu log
                raise HTTPException(status_code=400, detail=f"OpenRouter dice: {error_msg}")
            
            if 'choices' not in data:
                logger.error(f"X RESPUESTA INESPERADA: {data}")
                raise HTTPException(status_code=500, detail="OpenRouter no envió respuesta válida")

            response_text = data['choices'][0]['message']['content']
        
        else:
            # Lógica de Mistral (Local)
            payload = {
                "model": "mistral:7b-instruct-v0.3-q4_K_M", # Aqui especificas el modelo AI
                "prompt": last_message,
                "stream": False,
                "options": {"num_predict": 500}
            }
            r = requests.post(OLLAMA_URL, json=payload, timeout=60)
            data = r.json()
            response_text = data.get("response", "").strip()

    except Exception as e:
        logger.error(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

    # Formato OpenAI para Open WebUI
    return {
        "id": f"chatcmpl-{int(time.time())}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": model_used,
        "choices": [{"index": 0, "message": {"role": "assistant", "content": response_text}, "finish_reason": "stop"}]
    }