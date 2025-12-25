#!/bin/bash

# --- CONFIGURACIÓN VISUAL ---
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- NOMBRE DEL CONTENEDOR ---
# Asegúrate de que esto coincida con tu docker-compose.yml
CONTAINER_NAME="ia-api"

# --- FUNCIÓN DE ENCABEZADO ---
show_header() {
    clear
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${CYAN}        NEXUS AI CONTROL CENTER  v1.0      ${NC}"
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
    echo -e "Estado del Sistema: ${GREEN}OPERATIVO${NC}"
    echo -e "-------------------------------------------------"
    echo -e "${GREEN}1) Desplegar / Actualizar NexusAI (Build & Up)${NC}"
    echo -e "${YELLOW}2) Reiniciar Gateway (API Only)${NC}"
    echo -e "${CYAN}3) Monitor de Logs (Tiempo Real)${NC}"
    echo -e "${RED}4) Apagar Sistema (Down)${NC}"
    echo -e "5) Salir"
    echo ""
    read -p "Comando [1-5]: " option

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
            echo -e "\n${YELLOW}>> [NexusAI] Reiniciando núcleo (ia-api)...${NC}"
            docker restart $CONTAINER_NAME
            echo -e "\n${GREEN}✅ [NexusAI] Gateway reiniciado.${NC}"
            read -p "Presiona Enter para continuar..."
            ;;
        3)
            echo -e "\n${CYAN}>> [NexusAI] Conectando al stream de datos...${NC}"
            echo -e "${YELLOW}(Presiona CTRL+C para salir del monitor)${NC}"
            sleep 1
            docker logs -f $CONTAINER_NAME
            ;;
        4)
            echo -e "\n${RED}>> [NexusAI] Desactivando nodos...${NC}"
            docker-compose down
            echo -e "\n${RED} [NexusAI] Sistema detenido.${NC}"
            read -p "Presiona Enter para continuar..."
            ;;
        5)
            echo -e "\n Cerrando sesión NexusAI. Buen turno."
            exit 0
            ;;
        *)
            echo -e "\n${RED}❌ Comando desconocido.${NC}"
            sleep 1
            ;;
    esac
done