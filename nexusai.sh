#!/bin/bash

# --- CONFIGURACIÓN VISUAL ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# --- NOMBRE DEL CONTENEDOR ---
# Asegúrate de que esto coincida con tu docker-compose.yml
CONTAINER_NAME="ia-api"
CONTAINER_OLLAMA="ollama"

# --- Estado del ia-api ---
ESTADO_SISTEMA() {
    # 1. Ejecutar docker ps -a y filtrar por el nombre del contenedor.
    # 2. Usar 'grep Up' para ver si está en estado 'Up' (Running).
    # 3. Si se encuentra la palabra 'Up', el contenedor está OPERATIVO.
    # 4. Si no, se asume APAGADO (o en otro estado como Exited).
    if docker ps --filter "name=${CONTAINER_NAME}" --format '{{.State}}' | grep -q "running"; then
        echo -e "${GREEN}OPERATIVO${NC}"
    else
        # Si el contenedor existe pero no está corriendo, o si no existe en 'ps -a'.
        echo -e "${RED}APAGADO${NC}"
    fi
}

# --- FUNCIÓN DE ENCABEZADO ---
show_header() {
    clear
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${CYAN}        NEXUS AI CONTROL CENTER  v1.5      ${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${RED}                    CONTROL                ${NC} "
    echo -e "${CYAN}============ Estado del Sistema: $(ESTADO_SISTEMA) ${NC} "
    echo -e "${CYAN}=================================================${NC}"
    echo ""
}

# --- VERIFICACIÓN DE ROOT ---
if [ "$EUID" -ne 0 ]; then 
  echo -e "${YELLOW}⚠️  Acceso denegado. Ejecuta como administrador:${NC}"
  echo -e "   sudo ./nexus.sh"
  exit
fi

# --- BUCLE PRINCIPAL ---
while true; do
    show_header
    echo -e "${GREEN}1) Desplegar / Actualizar NexusAI (Build & Up)${NC}"
    echo -e "${MAGENTA}2) Instalar Nuevo Modelo en Ollama (DeepSeek/Llama)${NC}"
    echo -e "${RED}3) Eliminar Modelo (Remove)${NC}"
    echo -e "${YELLOW}4) Reiniciar Gateway (API Only)${NC}"
    echo -e "${CYAN}5) Monitor de Logs (Tiempo Real)${NC}"
    echo -e "${RED}6) Apagar Sistema (Down)${NC}"
    echo -e "7) Salir"
    echo ""
    read -p "Comando [1-7]: " option

    case $option in
        1)
            echo -e "\n${CYAN}>> [NexusAI] Inicializando protocolos de despliegue...${NC}"
            echo -e "${CYAN}>> Cargando variables desde api/.env...${NC}"
            
            # Forzamos la carga del archivo .env para evitar errores con sudo
            docker-compose --env-file api/.env up -d --build
            
            echo -e "\n${GREEN}✅ [NexusAI] Sistema desplegado correctamente.${NC}"
            read -p "Presiona Enter para continuar..."
            ;;
        2)
            # VERIFICAR SI OLLAMA ESTÁ CORRIENDO
            if [ "$(docker ps -q -f name=$CONTAINER_OLLAMA)" ]; then
                echo -e "\n${MAGENTA}>> Introduce el nombre del modelo (ej: deepseek-r1, llama3, mistral):${NC}"
                read -p "Nombre del modelo: " model_name
                
                if [ -n "$model_name" ]; then
                    echo -e "\n${YELLOW}>> Conectando a Ollama Hub... Descargando $model_name...${NC}"
                    echo -e "${CYAN}(Esto dependerá de tu velocidad de internet)${NC}\n"
                    
                    # EJECUCIÓN DEL COMANDO DENTRO DE DOCKER
                    docker exec -it $CONTAINER_OLLAMA ollama pull "$model_name"
                    
                    echo -e "\n${GREEN}✅ Instalación finalizada. Ya puedes usar '$model_name'.${NC}"
                else
                    echo -e "\n${RED}❌ Nombre inválido.${NC}"
                fi
            else
                echo -e "\n${RED}⚠️  ERROR: El contenedor de Ollama no está activo.${NC}"
                echo -e "Primero ejecuta la opción 1 para encender el sistema."
            fi
            read -p "Presiona Enter para continuar..."
            ;;
        3)
            # FUNCIÓN DE ELIMINACIÓN
            if [ "$(docker ps -q -f name=$CONTAINER_OLLAMA)" ]; then
                echo -e "\n${RED}>> LISTA DE MODELOS INSTALADOS:${NC}"
                # Listamos los modelos para que sepas cuál borrar
                docker exec $CONTAINER_OLLAMA ollama list
                echo ""
                echo -e "${YELLOW}>> Escribe el nombre exacto del modelo a eliminar (o 'cancelar'):${NC}"
                read -p "Nombre a eliminar: " model_del
                
                if [[ "$model_del" != "cancelar" && -n "$model_del" ]]; then
                    echo -e "\n${RED}>> Eliminando $model_del...${NC}"
                    docker exec -it $CONTAINER_OLLAMA ollama rm "$model_del"
                    echo -e "\n${GREEN}✅ Modelo eliminado correctamente.${NC}"
                else
                    echo -e "\n${CYAN}Operación cancelada.${NC}"
                fi
            else
                echo -e "\n${RED}⚠️  ERROR: Ollama no está activo. Ejecuta la opción 1 primero.${NC}"
            fi
            read -p "Presiona Enter para continuar..."
            ;;
        4)
            echo -e "\n${YELLOW}>> [NexusAI] Reiniciando núcleo (ia-api)...${NC}"
            docker restart $CONTAINER_NAME
            echo -e "\n${GREEN}✅ [NexusAI] Gateway reiniciado.${NC}"
            read -p "Presiona Enter para continuar..."
            ;;
        5)
            echo -e "\n${CYAN}>> [NexusAI] Conectando al stream de datos...${NC}"
            echo -e "${YELLOW}(Presiona CTRL+C para salir del monitor)${NC}"
            sleep 1
            docker logs -f $CONTAINER_NAME
            ;;
        6)
            echo -e "\n${RED}>> [NexusAI] Desactivando nodos...${NC}"
            docker-compose down
            echo -e "\n${RED} [NexusAI] Sistema detenido.${NC}"
            read -p "Presiona Enter para continuar..."
            ;;
        7)
            echo -e "\n Cerrando sesión NexusAI. Buen turno."
            exit 0
            ;;
        *)
            echo -e "\n${RED}❌ Comando desconocido.${NC}"
            sleep 1
            ;;
    esac
done