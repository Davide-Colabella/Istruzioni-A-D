# A/D

# Introduzione

Ciao a tutti, queste sono delle istruzioni utili per le simulazioni di A/D(Attack & Defence). Per farla breve una competizione dove ogni team avrà a propria disposizione una macchina con n servizi che presentano delle vulnerabilità. La finalità della competizione è attaccare per rubare le flag (rubare e inviare una flag al game server permette di guadagnare punti) e difendersi tramite patch o utilizzando software dedicati per bloccare richieste malevole (negare con criterio ovviamente, altrimenti bloccarle completamente è una violazione del regolamento).

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
sudo wg-quick up <$PWD/file.conf">
```

`$PWD` indica la directory corrente, quindi se il file `player.conf` è nella directory corrente possiamo lanciare il comando così, altrimenti dobbiamo specificare il path completo.

Per disconnetterci:

```sh
sudo wg-quick down <$PWD/file.conf>
```

# `ssh` (Secure SHell)

Una volta sulla vpn della cc potremo accedere alla vulnbox, con l'utilizzo stavolta di `ssh` (secure shell), da cui avremo quindi una shell sulla macchina, quindi possiamo sia inviare comandi che esplorare un po' a mano i servizi.

Per poterci connettere in ssh dovremo utilizzare delle key, che vanno prima generate e poi associate alla vulnbox, quindi in ordine lanciamo:

Genera la chiave ssh:
```sh
ssh-keygen -t rsa -b 4096 -f "<Nome chiave>" -N ""
```

Genero la chiave ssh dandole un nome e senza password, in modo che non mi chieda la password ogni volta che mi connetto.

Copia la chiave alla vulnbox:
```sh
ssh-copy-id -i "$file_key.pub" -o StrictHostKeyChecking=no root@<vulnbox-ip>
```

Stabilisce la connessione ssh:
```sh
ssh -o StrictHostKeyChecking=no -i key.pub root@<vulnbox-ip>
```

# `scp` (Secure copy protocol)

Successivamente la cosa migliore da fare prima di partire è salvare in locale una copia dei servizi della macchina virtuale, possiamo farlo col comando `scp`:

```sh
sudo apt install scp
```
```sh
scp -o StrictHostKeyChecking=no -i key.pub -r root@<vulnbox-ip>:~/ ./originale
```


# `sshfs` (Secure SHell FileSystem)

Poi andremo a montare (collegare in pratica) la cartella della vulnbox sul nostro pc utilizzanso `sshfs`:

Assicuratevi di avere già una cartella dove montare la vulnbox altrimenti sshfs andrà in errore.

Montare la cartella dalla vulnbox sulla nostra macchina:
```sh
sshfs root@<vulnbox-ip>:/root /vulnbox -o IdentityFile=key.pub
```

Smontare la cartella:
```sh
fusermount -u /vulnbox
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

I comandi di tipo compose vanno lanciati all'interno della cartella root del servizio dove troviamo il file `docker-compose.yml`, in questo modo se abbiamo fatto delle patch possiamo applicarle lanciando `docker compose up -d --build`.
# Caronte

Iniziamo ad introdurre i tool che ci daranno una mano per capire come veniamo attaccati e bloccare gli attacchi. Caronte è uno strumento per analizzare il flusso di rete durante gli eventi di tipo attacco/difesa come Capture The Flag. Riassimila i pacchetti TCP catturati nei file pcap per ricostruire le connessioni TCP e analizza ciascuna connessione per trovare pattern definiti dall'utente.

Vi do lo script utilizzato l'anno scorso per scaricare e avviare caronte, avremo poi un'interfaccia su `http://Ip_Vulnbox:3333` dove visualizzare tutti i pacchetti catturati:


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
    "server_address": "Ip_Vulnbox", #DA CAMBIARE
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

Composto da una parte client e da una parte server, il rapporto server-client è 1 a molti.

Avremo quindi un Farm server avviato sulla vulnbox o sul vostro pc e n Farm client avviati sui vostri pc.

## Farm server:

Il Farm server è uno strumento che raccoglie flag dai vari Farm Client e le invia al gameserver, mostrando lo stato di ogni flag inviata (accettata, in attesa, rifiutata) e i punti ottenuti da questa flag.

Ora abbiamo due modi per avviarlo, utilizzare la versione pre-configurata che vi allego qui sotto dove dovremo modificare solamente un paio di parametri oppure clonare la repo da git e creare a mano dei file per farla funzionare:

Struttura DestructiveFarm:

```
Destructive_Farm
├───.git
├───client
├───docs
├───server
│   ├───protocols
│   ├───static
│   ├───templates
│   └───__pycache__
└───tests
```

### 1. Setup server di DestructiveFarm clonato da github:

Partiamo con:
```sh 
git clone https://github.com/borzunov/DestructiveFarm
cd DestructiveFarm/server/
```

Ora dobbiamo creare il file `cyberchallengectf_http.py` nella cartella `protocols`:

```sh
cd protocols/
nano cyberchallengectf_http.py
```

e mettiamo questo:

```py
import requests

from server import app
from server.models import FlagStatus, SubmitResult


RESPONSES = {
FlagStatus.QUEUED: ['timeout', 'game not started', 'try again later', 'game over', 'is not up', 'no such flag'], 
FlagStatus.ACCEPTED: ['accepted', 'congrat'], 
FlagStatus.REJECTED: ['invalid flag', 'flag from nop team', 'own', 'old', 'claimed', 'bad', 'wrong', 'expired', 'unknown', 'your own', 'too old', 'not in database', 'already submitted', 'invalid flag'],
}


def submit_flags(flags, config):
	r = requests.put(
		config['SYSTEM_URL'], 
		headers={'X-Team-Token': config['SYSTEM_TOKEN']}, 
		json=[item.flag for item in flags], 
		timeout=5
		)

	# log 
	
	unknown_responses = set()
	for item in r.json():
		response = item['msg'].strip()
		response = response.replace('[{}] '.format(item['flag']), '')
		response_lower = response.lower()

		for status, substrings in RESPONSES.items():
			if any(s in response_lower for s in substrings):
				found_status = status
				break
		else:
			found_status = FlagStatus.QUEUED
			if response not in unknown_responses:
				unknown_responses.add(response)
				app.logger.warning('Unknown checksystem response (flag will be resent): %s', response)

		yield SubmitResult(item['flag'], found_status, response)

```

Infine:

```sh
cd ../
nano start_sploit.py
```

e cambiamo:

```py
parser.add_argument('-u', '--server-url', metavar='URL',
                        default='http://farm.kolambda.com:5000',
                        help='Server URL')
```

in:

```py
parser.add_argument('-u', '--server-url', metavar='URL',
                        default='http://localhost:5000',
                        help='Server URL')
```

In caso di conflitti di porte con i servizi della vulnbox potete cambiare la porta con cui parte Farm server.

ora seguiamo la procedura identica al DestructiveFarm pre-configurato.

### 2. Setup server pre-configurato:


Andiamo nella cartella server e modifichiamo il file `config.py`:

```sh
cd DestructiveFarm/server/
nano config.py
```
Ho utilizzato nano, ma potete utilizzare un qualsiasi editor di testo


Apportiamo le seguenti modifiche:

```py
# CAMBIARE I RANGE A SECONDA DELLA SIMULAZIONE O PER LA GARA NAZIONALE
    'TEAMS': {'Team #{}'.format(i): '10.60.{}.1'.format(i)
              for i in range(1, 43) if i != 30},
    'FLAG_FORMAT': r'^[A-Z0-9]{31}=$',
```

```py
'SYSTEM_PROTOCOL': 'cyberchallengectf_http',
'SYSTEM_URL': 'http://10.10.0.1:8080/flags',
# CAMBIARE CON IL TEAM TOKEN DEL PROPRIO TEAM
'SYSTEM_TOKEN': '30cf9b97e01a39a03b75895f090b7982',
```
```py
'SERVER_PASSWORD': 'GfPbHr1qCShjb097',
```
Le cose da cambiare sono: 
- il range con cui cicla sui team e il not affianco (attualmente è settato per 42 team e deve saltare il 30, che saremmo noi)
- il valore di `SYSTEM_TOKEN`
- la password per connetterci a destructiveFarm

Per avviarlo lanciamo:

```sh
python3 -m pip install -r requirements.txt
chmod +x start_server.sh
./start_server.sh
```

## Farm Client:

Il Farm Client è uno strumento che periodicamente esegue exploit per attaccare altri team e monitorare il loro lavoro. Viene eseguito da un partecipante sul proprio laptop dopo aver scritto un exploit.

Bisogna avviare un client per exploit.

Con Farm Server avviato e un file exploit, possiamo lanciare Farm Client così:

```sh
./start_sploit.py sploit.py -u http://{ip}:{porta}
```

dove `sploit.py` è il file contentente l'exploit, `ip` l'indirizzo della macchina su cui è avviato Farm server e `porta` la porta su cui è disponibile Farm server.

Se avete più script dovete avviare più processi di Farm Client aprendo più finestre terminali o utilizzando `tmux` utile per sdoppiare una singola finestra del terminale in più terminali.

![Cheat-Sheet Rapida](https://www.themoderncoder.com/uploads/simple-tmux-cheatsheet.jpg)

[Cheat-Sheet dei comandi](https://gist.github.com/MohamedAlaa/2961058)

# Setup della vostra macchina

Per poter lavorare il più velocemente possibile vi consiglio di installare i tool visti prima utilizzando lo script che ho preparato per voi:

Da dentro la vostra macchina le uniche cose richieste sono avere il file di configurazione della vpn e i dati di accesso alla vulnbox.
Potete copiarlo interamente e copiarlo nella shell:

```sh
mkdir ~/ad
cd ~/ad
wget https://raw.githubusercontent.com/Davide-Colabella/Istruzioni-A-D/main/setup.sh
chmod +x setup.sh
./setup.sh
```

Lo script scaricherà e installerà tutti i tool necessari per la competizione, vi basterà solo inserire i dati di accesso alla vpn e alla vulnbox.

# Setup della vulnbox

Avviate Caronte seguendo le istruzioni riportate sopra, poi per avviare DestructiveFarm sulla vulnbox, ricordate che c'è un solo server e N client, quindi avviate il server sulla vulnbox e i client sulle vostre macchine.



