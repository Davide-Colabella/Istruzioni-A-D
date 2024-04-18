# A/D

# Introduzione

Ciao a tutti, come avrete visto dalle mail nella giornata di domani partiranno le simulazioni di A/D(Attack & Defence). Per farla breve una competizione dove ogni team avrà a propria disposizione una macchina con n servizi che presentano delle vulnerabilità. La finalità della competizione è attaccare per rubare le flag (rubare e inviare una flag al game server permette di guadagnare punti) e difendersi tramite patch o utilizzando software dedicati per bloccare richieste malevole (negare con criterio ovviamente, altrimenti bloccarle completamente è una violazione del regolamento).

[Regolamento A/D](https://rules.ad.cyberchallenge.it/)

Per accedere alla competizione dovremo utilizzare la rete virtuale creata dagli organizzatori.

![Struttura rete](https://rules.ad.cyberchallenge.it/static/img/network-1nop.svg)

Prima di partire vi faccio notare che i comandi e gli script allegati sono stati scritti per linux, quindi dovrete utilizzare la vostra vm con una distro linux oppure wsl/wsl2.

# Wireguard (VPN)

Dovremo connetterci alla vpn creata tramite l'utilizzo di wireguard, che tramite dei file `.conf` permettono il collegamento alla rete. Innanzitutto dovremo assicurarci di aver installato wireguard sulla nostra macchina, quindi:

- Ubuntu: 

```bash
sudo apt install wireguard
```

A questo punto possiamo connetterci con:

```sh
sudo wg-quick up <file.conf>
```

Per disconnetterci:

```sh
sudo wg-quick down <file.conf>
```

# `ssh` (Secure SHell)

Una volta sulla vpn della cc potremo accedere alla vulnbox, con l'utilizzo stavolta di `ssh` (secure shell), da cui avremo quindi una shell sulla macchina, quindi possiamo sia inviare comandi che esplorare un po' a mano i servizi.

Per poterci connettere in ssh dovremo utilizzare delle key, che vanno prima generate e poi associate alla vulnbox, quindi in ordine lanciamo:

Genera la chiave ssh:
```sh
ssh-keygen -t ed25519 -C comment
```

Copia la chiave alla vulnbox:
```sh
ssh-copy-id -i ~/.ssh/<your_key> root@<vulnbox-ip>
```

Stabilisce la connessione ssh:
```sh
ssh -i ~/.ssh/<your_key> root@<vulnbox-ip>
```

# `scp` (Secure copy protocol)

Successivamente la cosa migliore da fare prima di partire è salvare in locale una copia dei servizi della macchina virtuale, possiamo farlo col comando `scp`:

```sh
sudo apt install scp
```
```sh
scp -i ~/.ssh/<your_key> -r root@<vulnbox-ip>:/root/ ./originale
```


# `sshfs` (Secure SHell FileSystem)

Poi andremo a montare (collegare in pratica) la cartella della vulnbox sul nostro pc utilizzanso `sshfs`:

Montare la cartella dalla vulnbox sulla nostra macchina:
```sh
sshfs root@<vulnbox-ip>:/root /mnt/vulnbox -o IdentityFile=.ssh/<your_key>
```

Smontare la cartella:
```sh
fusermount -u /mnt/vulnbox
```

<b>IMPORTANTISSIMO: se fate modifiche sulla cartella montata queste verranno riflesse anche sulla vulnbox, quindi non fate cose come eliminare file/cartelle, altrimenti sono *****!</b>

Andiamo a montare la cartella per poterci lavorare sul nostro IDE e poter applicare in modo veloce le patch. Ma attenti sempre ad avere una copia originale del servizio.

# Docker

Docker è una piattaforma di sviluppo che semplifica la creazione, la distribuzione e l'esecuzione di applicazioni utilizzando container. I container sono ambienti virtualizzati leggeri che includono tutto il necessario per eseguire un'applicazione, come codice, librerie e dipendenze, garantendo portabilità e consistenza tra ambienti di sviluppo e produzione. Molti se non tutti i servizi girano su docker, quindi è importante conoscere i suoi comandi:

Elenca i container Docker attivi:
```sh
docker ps
```

Avvia il container Docker Compose:
```sh
docker compose up -d
```

Riavvia il container Docker Compose:
```sh
docker compose restart
```

Arresta il container Docker Compose:
```sh
docker compose down
```

Ricostruisci e avvia il container Docker Compose:
```sh
docker compose up -d --build
```

# Caronte

Iniziamo ad introdurre i tool che ci daranno una mano per capire come veniamo attaccati e bloccare gli attacchi. Caronte è uno strumento per analizzare il flusso di rete durante gli eventi di tipo attacco/difesa come Capture The Flag. Riassimila i pacchetti TCP catturati nei file pcap per ricostruire le connessioni TCP e analizza ciascuna connessione per trovare pattern definiti dall'utente.

Vi do lo script utilizzato l'anno scorso per scaricare e avviare caronte, avremo poi un'interfaccia su `http://localhost:3333` dove visualizzare tutti i pacchetti catturati:


- caronte.sh:
```sh 
#!/bin/bash

git clone https://github.com/eciavatta/caronte.git
cd caronte
docker compose up -d
sleep 3
curl -X 'POST' \
  'http://localhost:3333/setup' \
  -H 'accept: */*' \
  -H 'Content-Type: application/json' \
  -d '{
  "config": {
    "server_address": "10.60.41.1",
    "flag_regex": "[A-Z0-9]{31}=",
    "auth_required": true
  },
  "accounts": {
    "univpm": "x2o2x7D45mFFhv0q" #DA CAMBIARE
  }
}'
```

I pacchetti non vengono catturati automaticamente, ma bisogna passarglieli:

- dump_daemon.sh:
```sh
#!/bin/bash

mkdir /tmp/captures

while [ 1 = 1 ]
do
  name="$(date -Iseconds).pcap"
  timeout 20 tcpdump -i game -s0 -w "/tmp/captures/${name}" 'not port 22 && not port 3333'
  #mv "/root/captures/latest.pcap" "$1/${name}"
  curl -F "file=@/tmp/captures/${name}" "http://localhost:3333/api/pcap/upload" --user "univpm:x2o2x7D45mFFhv0q" #DA CAMBIARE
  rm "/tmp/captures/${name}"
done
```

<b>Assicuratevi di cambiare i cambi username e password (potete scegliere quelli che volete, servono solo a voi, non hanno nulla a che fare con la connessione ssh alla vm), basta che siano uguali fra i due script.</b>

### Caronte andrà avviato una volta sola sulla vulnbox, poi sarà accessibile a tutti

# DestructiveFarm

Individuata la vulnerabilità e creato lo script ad hoc per estrarre la flag dovremmo lanciare lo script verso ogni team_ip e poi inviare la flag al game server. Per automatizzare questo processo abbiamo DestructiveFarm.

Vi consiglio di avviarlo sulla vostra macchina e non sulla vm perchè potrebbe essere molto pesante.

Composto da una parte client e da una parte server, il rapporto server-client è 1 a molti:

## Farm server:

Il Farm server è uno strumento che raccoglie flag dai vari Farm Client e le invia al gameserver, mostrando lo stato di ogni flag inviata (accettata, in attesa, rifiutata) e i punti ottenuti da questa flag.

Per installarlo:
```sh 
git clone https://github.com/borzunov/DestructiveFarm
cd DestructiveFarm/server
python3 -m pip install -r requirements.txt
```

## Farm Client:

Il Farm Client è uno strumento che periodicamente esegue exploit per attaccare altri team e monitorare il loro lavoro. Viene eseguito da un partecipante sul proprio laptop dopo aver scritto un exploit.

Bisogna avviare un client per exploit.

Con Farm Server avviato e un file exploit, possiamo lanciare Farm Client così:

```sh
./start_sploit.py sploit.py -u http://10.0.0.1:5000
```

dove `sploit.py` è il file contentente l'exploit e `http://10.0.0.1:5000` l'indirizzo della Farm Server.

Se avete più script dovete avviare più processi di Farm Client aprendo più finestre terminali o utilizzando `tmux` utile per sdoppiare una singola finestra del terminale in più terminali.

![Cheat-Sheet Rapida](https://www.themoderncoder.com/uploads/simple-tmux-cheatsheet.jpg)

[Cheat-Sheet dei comandi](https://gist.github.com/MohamedAlaa/2961058)

# Script per setup ssh e copia servizi

Salvando questo codice in un file.sh e sostituendo i valori indicati, quando verrà eseguito creerà la chiave ssh come `key`, copierà il contenuto della vulnbox in `/originale` e poi vi chiederà se volete connettervi in ssh.

Tutti i file generati dallo script verranno salvati nella posizione in cui viene eseguito.

Salvate nella stessa cartella script.sh e player.conf altrimenti non partirà.

```sh
#!/bin/bash

# Variabili inizializzate
file_key="$PWD/key"
file_conf="$PWD/player1.conf"
ip="10.60.41.1"  # Da sostituire con l'indirizzo IP corretto
username="root"  # Da sostituire con il nome utente corretto
password="x2o2x7D45mFFhv0q"  # Da sostituire con la password corretta

# Controlla se il file player.conf esiste
if [ ! -f "$file_conf" ]; then
    echo "Il file $file_conf non esiste. Lo script verrà interrotto."
    exit 1
fi

# Controlla se i pacchetti sono installati e installa quelli mancanti
if ! dpkg -s wireguard-tools fuse3 ssh sshfs sshpass >/dev/null 2>&1; then
    sudo apt install -y wireguard-tools fuse3 ssh sshfs sshpass
fi

# Disattiva qualsiasi VPN WireGuard attiva
echo "Disattivazione di qualsiasi VPN WireGuard attiva..."
sudo wg-quick down --all

# Attiva la VPN WireGuard corretta
echo "Attivazione della VPN WireGuard corretta..."
sudo wg-quick up "$file_conf"

# Genera le chiavi SSH se non esistono già e le copia sul server
if [ ! -f "$file_key" ] || [ ! -f "$file_key.pub" ]; then
    ssh-keygen -t ed25519 -C comment -f "$file_key" -N ""
fi
sshpass -p "$password" ssh-copy-id -i "$file_key.pub" "$username@$ip"

# Verifica se la cartella "originale" esiste e contiene file
if [ -d "originale" ] && [ "$(ls -A originale)" ]; then
    echo "La cartella 'originale' esiste e contiene file. Non viene rifatta la copia dal server."
else
    # Rimuove la directory "originale" se esiste e scarica la directory originale dal server
    if [ -d "originale" ]; then
        rm -rf "originale"
    fi
    scp -i "$file_key" -r "$username@$ip":/root/ ./originale
fi

# Smonta la cartella "vulnbox" se è già montata e monta il file system remoto
if mountpoint -q ./vulnbox; then
    fusermount -u ./vulnbox
fi
if [ ! -d "vulnbox" ]; then
    mkdir vulnbox
fi
sshfs "$username@$ip":/root ./vulnbox -o IdentityFile="$file_key"

# Chiede all'utente se desidera connettersi alla VM tramite SSH
read -p "Desideri connetterti alla VM? (sì/no): " choice
if [ "$choice" = "si" ] || [ "$choice" = "sì" ]; then
    ssh -o StrictHostKeyChecking=no -i "$file_key" "$username@$ip"
else
    echo "Esecuzione terminata."
fi
```