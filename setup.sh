#!/bin/bash

# Variabili inizializzate
file_key="$PWD/key"
file_conf="$PWD/player.conf"
interface="player"
config_file="$PWD/.setup_config"
ip=""
username="root"
password=""

#Colors
Color_Off='\033[0m'
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Carica le impostazioni dal file di configurazione se esiste
if [ -f "$config_file" ]; then
    source "$config_file"
fi

# Funzione per salvare le impostazioni nel file di configurazione
save_config() {
    echo "ip=\"$ip\"" > "$config_file"
    echo "password=\"$password\"" >> "$config_file"
}

# Funzione per controllare e installare i pacchetti mancanti
check_and_install_packages() {
    if ! dpkg -s wireguard-tools fuse3 ssh sshfs sshpass >/dev/null 2>&1; then
        echo -e "${Yellow}Sto installando dei pacchetti mancanti...${Color_Off}"
        sudo apt install -y wireguard-tools fuse3 ssh sshfs sshpass
        clear
    fi
}

# Funzione per disattivare qualsiasi VPN WireGuard attiva
deactivate_wireguard() {
    echo -e "${Blue}Disattivazione della VPN WireGuard...${Color_Off}"
    sudo wg-quick down "$file_conf"
}

# Funzione per attivare la VPN WireGuard corretta
activate_wireguard() {
    echo -e "${Green}Attivazione della VPN WireGuard corretta...${Color_Off}"
    sudo wg-quick up "$file_conf"
}

# Funzione per generare le chiavi SSH e copiarle sul server
generate_and_copy_ssh_keys() {
    
    echo -e "${Yellow}Generazione delle chiavi SSH e copia sul server...${Color_Off}"

    if [ -z "$ip" ] || [ -z "$password" ]; then    
        read -p "Inserisci l'IP: " ip
        read -p "Inserisci la password: " -s password
    else
        echo -ne "${Blue}Utilizzare IP ($ip) e password ($password) salvati? (sì/no): ${Color_Off}"
        read use_saved
        if [ "$use_saved" = "no" ]; then
            read -p "Inserisci l'IP: " ip
            read -p "Inserisci la password: " -s password
        fi
    fi
    if [ -f "$file_key" ] || [ -f "$file_key" ]; then  
            rm -rf "$file_key" "$file_key.pub"
    fi
    # Genera le chiavi SSH
    ssh-keygen -t rsa -b 4096 -f "$file_key" -N ""

    # Copia la chiave pubblica sul server
    sshpass -p "$password" ssh-copy-id -i "$file_key.pub" -o StrictHostKeyChecking=no "$username@$ip"
    # Salva le impostazioni nel file di configurazione
    save_config
    echo -e "${Blue}Chiavi correttamente generate.${Color_Off}"
}

# Funzione per copiare in locale la vulnbox
copy_vulnbox_locally() {

    generate_and_copy_ssh_keys

    if [ -d "originale" ] && [ "$(ls -A originale)" ]; then
        echo -e "${Red}La cartella 'originale' esiste e contiene file. Non viene rifatta la copia dal server.${Color_Off}"
    else
        if [ -d "originale" ]; then
            rm -rf "originale"
        fi
        scp -o StrictHostKeyChecking=no -i "$file_key" -r "$username@$ip":~/ ./originale
    fi
}

# Funzione per montare la vulnbox
mount_vulnbox() {
    
    generate_and_copy_ssh_keys

    if mountpoint -q ./vulnbox; then
        echo -e "${Red}La cartella 'vulnbox' è già montata.${Color_Off}"
        return
    fi
    if [ ! -d "vulnbox" ]; then
        mkdir vulnbox
    fi
    sshfs "$username@$ip":/$username ./vulnbox -o IdentityFile="$file_key"
}

# Funzione per smontare la vulnbox se è già montata
unmount_vulnbox() {

    if mountpoint -q ./vulnbox; then
        fusermount -u ./vulnbox
        echo -e "${Blue}La cartella 'vulnbox' è stata smontata.${Color_Off}"
    else
        echo -e "${Red}La cartella 'vulnbox' non è montata.${Color_Off}"
    fi
}

# Funzione per connettersi alla VM tramite SSH
connect_to_vm() {
    generate_and_copy_ssh_keys
    ssh -o StrictHostKeyChecking=no -i "$file_key" "$username@$ip"
}

check_vpn() {
    if ! sudo wg show | grep -q "interface: $interface"; then
        echo -e "${Red}La VPN WireGuard non è attiva. La sto attivando...${Color_Off}"
        activate_wireguard
        return
    fi
}

exit_script() {
    echo
    echo -e "${Green}Esecuzione terminata, alla prossima!!${Color_Off}"
    sleep 1
    clear
    exit 0
}

# Funzione per il menu principale
main_menu() {
    while true; do
        clear
        check_and_install_packages
        cat << "EOF"
        
   _____      __                 _    __      __      __              
  / ___/___  / /___  ______     | |  / /_  __/ /___  / /_  ____  _  __
  \__ \/ _ \/ __/ / / / __ \    | | / / / / / / __ \/ __ \/ __ \| |/_/
 ___/ /  __/ /_/ /_/ / /_/ /    | |/ / /_/ / / / / / /_/ / /_/ />  <  
/____/\___/\__/\__,_/ .___/     |___/\__,_/_/_/ /_/_.___/\____/_/|_|  
                   /_/                                                


EOF
        PS3="
Scegli un'opzione: "
        options=("Setup VPN" "Spegni VPN" "Connessione vulnbox" "Copia in locale della vulnbox" "Mount della vulnbox" "Unmount della vulnbox" "Uscire")
        
        select opt in "${options[@]}"; do
            case $opt in
                "Setup VPN")
                    activate_wireguard
                    echo
                    ;;
                "Spegni VPN")
                    deactivate_wireguard
                    echo
                    ;;
                "Connessione vulnbox")  
                    check_vpn
                    connect_to_vm
                    echo
                    ;;
                "Copia in locale della vulnbox")
                    check_vpn
                    copy_vulnbox_locally
                    echo
                    ;;
                "Mount della vulnbox")
                    check_vpn
                    mount_vulnbox
                    echo
                    ;;
                "Unmount della vulnbox")
                    unmount_vulnbox
                    echo
                    ;;
                "Uscire")  
                    exit_script
                    ;;
                *)
                    echo "Scelta non valida."
                    sleep 0.5
                    clear
                    main_menu
                    ;;
            esac
            break
        done
        read -p $'Vuoi tornare al menu principale? (sì/no): ' return_choice
        if [ "$return_choice" = "no" ]; then
            exit_script
        fi
    done
}


# Esecuzione del menu principale
main_menu
