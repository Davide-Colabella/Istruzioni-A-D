#!/bin/bash

# Variabili inizializzate
file_key="$PWD/key"
file_conf="$PWD/player.conf"
interface="player"
config_file="$PWD/.my_script_config"
ip=""
username="root"
password=""

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
        echo -e "\e[1;32mSto installando dei pacchetti mancanti...\e[0m"
        sudo apt install -y wireguard-tools fuse3 ssh sshfs sshpass
        clear
    fi
}

# Funzione per disattivare qualsiasi VPN WireGuard attiva
deactivate_wireguard() {
    echo "Disattivazione della VPN WireGuard..."
    sudo wg-quick down "$file_conf"
}

# Funzione per attivare la VPN WireGuard corretta
activate_wireguard() {
    echo "Attivazione della VPN WireGuard corretta..."
    sudo wg-quick up "$file_conf"
}

# Funzione per generare le chiavi SSH e copiarle sul server
generate_and_copy_ssh_keys() {
    local print_echo="$1"

    # Verifica se nel file di configurazione sono presenti IP e password
    if [ -n "$ip" ] && [ -n "$password" ]; then
        # Controlla se le chiavi SSH esistono, altrimenti genera
        if [ ! -f "$file_key" ] || [ ! -f "$file_key.pub" ]; then
            echo "Le chiavi SSH non sono presenti. Generazione delle chiavi..."
            ssh-keygen -t rsa -b 4096 -f "$file_key" -N ""
            # Copia la chiave pubblica sul server
            sshpass -p "$password" ssh-copy-id -i "$file_key.pub" -o StrictHostKeyChecking=no "$username@$ip"
        fi
        return
    fi

    if [ ! -f "$file_key" ] || [ ! -f "$file_key.pub" ]; then
        if [ "$print_echo" = "true" ]; then
            echo
        fi
        echo "Generazione delle chiavi SSH e copia sul server..."
        echo
        read -p "Inserisci l'IP: " ip
        read -p "Inserisci la password: " -s password
        echo
        # Genera le chiavi SSH
        ssh-keygen -t rsa -b 4096 -f "$file_key" -N ""

        # Copia la chiave pubblica sul server
        sshpass -p "$password" ssh-copy-id -i "$file_key.pub" -o StrictHostKeyChecking=no "$username@$ip"
        # Salva le impostazioni nel file di configurazione
        save_config
    elif [ "$print_echo" = "true" ]; then
        echo "Le chiavi SSH esistono già."
    fi
}

# Funzione per copiare in locale la vulnbox
copy_vulnbox_locally() {
    if [ -n "$ip" ] && [ -n "$password" ]; then
        read -p "Utilizzare l'IP salvato ($ip) e la password salvata? (sì/no): " use_saved
        if [ "$use_saved" = "no" ]; then
            generate_and_copy_ssh_keys true
        fi
    else
        generate_and_copy_ssh_keys true
    fi
    if [ -d "originale" ] && [ "$(ls -A originale)" ]; then
        echo "La cartella 'originale' esiste e contiene file. Non viene rifatta la copia dal server."
    else
        if [ -d "originale" ]; then
            rm -rf "originale"
        fi
        scp -o StrictHostKeyChecking=no -i "$file_key" -r "$username@$ip":~/ ./originale
    fi
}

# Funzione per montare la vulnbox
mount_vulnbox() {
    if [ -n "$ip" ] && [ -n "$password" ]; then
        read -p "Utilizzare l'IP salvato ($ip) e la password salvata? (sì/no): " use_saved
        if [ "$use_saved" = "no" ]; then
            generate_and_copy_ssh_keys true
        fi
    else
        generate_and_copy_ssh_keys true
    fi
    if mountpoint -q ./vulnbox; then
        echo "La cartella 'vulnbox' è già montata."
        return
    fi
    if [ ! -d "vulnbox" ]; then
        mkdir vulnbox
    fi
    generate_and_copy_ssh_keys false
    sshfs "$username@$ip":/$username ./vulnbox -o IdentityFile="$file_key"
}

# Funzione per smontare la vulnbox se è già montata
unmount_vulnbox() {
    if mountpoint -q ./vulnbox; then
        fusermount -u ./vulnbox
        echo "La cartella 'vulnbox' è stata smontata."
    else
        echo "La cartella 'vulnbox' non è montata."
    fi
}

# Funzione per connettersi alla VM tramite SSH
connect_to_vm() {
    
    if [ -n "$ip" ] && [ -n "$password" ]; then
        read -p "Utilizzare l'IP salvato ($ip) e la password salvata? (sì/no): " use_saved
        if [ "$use_saved" = "no" ]; then
            generate_and_copy_ssh_keys true
        fi
    else
        generate_and_copy_ssh_keys true
    fi
    if [ ! -f "$file_key" ] || [ ! -f "$file_key.pub" ]; then
        echo "Le chiavi SSH non sono presenti. Generazione delle chiavi..."
        generate_and_copy_ssh_keys false
    fi
    ssh -o StrictHostKeyChecking=no -i "$file_key" "$username@$ip"
}

check_vpn() {
    if ! sudo wg show | grep -q "interface: $interface"; then
        echo "La VPN WireGuard non è attiva. La sto attivando..."
        activate_wireguard
        return
    fi
}

# Funzione per il menu principale
main_menu() {
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
    echo -e "Menu principale:\n"
    echo "1) Setup VPN"
    echo "2) Spegni VPN"
    echo "3) Generazione key"
    echo "4) Connessione vulnbox"
    echo "5) Copia in locale della vulnbox"
    echo "6) Mount della vulnbox"
    echo "7) Unmount della vulnbox"
    echo -e "8) Uscire\n"
    read -p "Scelta: " choice
    case $choice in
        1)
            activate_wireguard
            ;;
        2)
            deactivate_wireguard
            ;;
        3)
            check_vpn
            generate_and_copy_ssh_keys true
            ;;
        4)  
            check_vpn
            connect_to_vm
            ;;
        5)
            check_vpn
            copy_vulnbox_locally
            ;;
        6)
            check_vpn
            mount_vulnbox
            ;;
        7)
            unmount_vulnbox
            ;;
        8)
            clear
            exit 0
            ;;
        *)
            echo "Scelta non valida."
            sleep 0.5
            clear
            main_menu
            ;;
    esac

    read -p "Vuoi tornare al menu principale? (sì/no): " return_choice
    if [ "$return_choice" = "no" ]; then
        echo -e "\e[1;32mEsecuzione terminata.\e[0m"
        sleep 0.5
        clear
        exit 0
    else
        clear
        main_menu
    fi
}

# Esecuzione del menu principale
main_menu
