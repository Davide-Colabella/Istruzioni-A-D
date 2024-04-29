#!/bin/bash

file_key="$PWD/key"
file_conf="$PWD/player1.conf"
ip="10.60.41.1"  # Da sostituire con l'indirizzo IP corretto
username="root"  # Da sostituire con il nome utente corretto
password="x2o2x7D45mFFhv0q"  # Da sostituire con la password corretta

# Controlla se i pacchetti sono già installati
if ! dpkg -s ssh sshfs sshpass >/dev/null 2>&1; then
    sudo apt install -y ssh sshfs sshpass
fi

echo -e "$password\n$password" | sudo passwd "$username"

# Genera le chiavi SSH
if [ ! -f "$file_key" ] || [ ! -f "$file_key.pub" ]; then
    ssh-keygen -t ed25519 -C comment -f "$file_key" -N ""
fi

sshpass -p "$password" ssh-copy-id -i "$file_key.pub" "$username@$ip"

# Verifica se la cartella "originale" esiste e contiene file
if [ -d "originale" ] && [ "$(ls -A originale)" ]; then
    echo "La cartella 'originale' esiste e contiene file. Non viene rifatta la copia dal server."
else
    # Rimuove la directory "originale" se esiste
    if [ -d "originale" ]; then
        rm -rf "originale"
    fi

    # Scarica la directory originale dal server
    scp -i "$file_key" -r "$username@$ip":/root/ ./originale
fi

# Smonta la cartella "vulnbox" se è già montata
if mountpoint -q ./vulnbox; then
    fusermount -u ./vulnbox
fi

# Crea la directory vulnbox e monta il file system remoto
if [ ! -d "vulnbox" ]; then
    mkdir vulnbox
fi
sshfs "$username@$ip":/root ./vulnbox -o IdentityFile="$file_key"

# Chiedi all'utente se desidera connettersi alla VM o uscire dall'esecuzione
read -p "Desideri connetterti alla VM? (sì/no): " choice
if [ "$choice" = "si" ] || [ "$choice" = "sì" ]; then
    ssh -o StrictHostKeyChecking=no -i "$file_key" "$username@$ip"
else
    echo "Esecuzione terminata."
fi