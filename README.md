# Agent skills

Een openbare bronrepository voor persoonlijke skills en een gecontroleerde
kopie van Matt Pococks volledige stabiele skillset:
[robelene112/agent-skills](https://github.com/robelene112/agent-skills).

| Onderdeel | Locatie | Status |
| --- | --- | --- |
| Saito-ontwikkeling | [saito-dev](skills/saito-dev/SKILL.md) | Herzien voorstel, nog niet geactiveerd |
| Odoo 20-frameworkkennis | [odoo-20](skills/odoo-20/SKILL.md) | Geïnstalleerd in het Odoo BI-project |
| Globale communicatieregels | [global-communication](skills/global-communication/SKILL.md) | Geen em dashes; vragen in de chat; tijdens een grill één vraag per keer |
| Bestanden en werkaantekeningen | [workspace-hygiene](skills/workspace-hygiene/SKILL.md) | Intern onderzoek blijft in de sessie of tijdelijke opslag; blijvende bestanden hebben een duidelijk doel |
| Tracker voor ontwikkeling | [github-issues](skills/github-issues/SKILL.md) | Nieuwe tickets en trackerspecificaties zijn GitHub Issues |
| Programmeerregels | [development-preferences](skills/development-preferences/SKILL.md) | Gebruikerservaring boven developer experience, doordachte defaults en verzorgde UI; geen cyberwerk met beperkte toegang |
| Lokale Outlook-mail | [outlook-local](skills/outlook-local/SKILL.md) | Windows/WSL met klassiek Outlook; zoeken en volledig lezen live getest, ongelezenstatus bleef behouden |
| Actief letten op updates | [proactive-updates](skills/proactive-updates/SKILL.md) | Globale onderhoudsaandacht tijdens software- en omgevingswerk |
| Globale instructie-ingang | [AGENTS.md](instructions/global/AGENTS.md) | Laadt de persoonlijke regels |
| VPS-opslag | [Storage](environments/vps/STORAGE.md) | Alleen voor de VPS; `/` en `/mnt/storage` |
| Matt Pocock | [Upstream skills](vendor/matt-pocock/skills/) | Ongewijzigde, gecontroleerde snapshot |
| Beoordeling van bestaande skills | [Review](docs/REVIEW.md) | Behouden, verplaatsen en vervangen onderbouwd |
| Bron en bestandscontrole | [source.json](vendor/matt-pocock/source.json) | Actuele bronrevision en SHA-256-hashes |

`dev-loop` is op verzoek verwijderd, inclusief de globale, lokale Odoo- en oude
laptopvarianten op de VPS. Ontwikkeling gebruikt Matt Pococks skills rechtstreeks
en volgt de projectafspraken. De voorkeur om na een afgeronde grill zelfstandig
de afgesproken keten af te werken hoort bij de opdracht of projectworkflow.
In het bijzonder blijft Red Square opeenvolgende ticketimplementatie gebruiken.

`saito-dev` is nog een herzien voorstel. De geïnstalleerde versie is nog actief
en wordt afzonderlijk beoordeeld. Het voorstel houdt Saito-specifieke
beslisregels bij elkaar en laadt operationele details alleen wanneer nodig.

`odoo-20` vervangt de oude Odoo 19-skill en Claude-kopieën op de VPS. De skill
bevat uitsluitend frameworkkennis: ORM en beveiliging, Owl en controllers,
moduledata en tests, plus verwijzingen naar primaire bronnen. De Odoo BI-installatie
staat in `.agents/skills/odoo-20/`; Claude gebruikt een link naar diezelfde map.
Ontwikkelflow, projectdomein en omgeving blijven in hun bestaande bronnen.

De communicatie- en trackerregels zijn persoonlijk en gelden in alle omgevingen.
De VPS-opslagnotitie is uitsluitend voor die machine. Bestaande lokale tickets
blijven bestaande administratie; de nieuwe afspraak voert geen automatische
migratie van oude plannen uit.

De globale bestandsregel voorkomt ongevraagde onderzoeksrapporten en andere
werkaantekeningen in projectmappen. Onderzoek voor de agent zelf blijft standaard
in de sessie; noodzakelijke tijdelijke bestanden gaan naar een tijdelijke map
buiten het project en worden opgeruimd zodra ze niet meer nodig zijn. Code,
tests, assets en gevraagde documenten horen op hun bestaande plek. Leg concrete
projectkennis die volgende agents helpt compact vast in bestaande documentatie;
algemeen achtergrondonderzoek is geen reden om een heel rapport te bewaren.
Onderzoek naar effectieve logo's dient bijvoorbeeld om logo's op te leveren
waaruit David kan kiezen. Controleer aan het einde welke bestanden zijn toegevoegd
en of die bij het gevraagde resultaat horen. Een adviesvraag geeft op zichzelf
geen opdracht om bestanden te wijzigen of wijzigingen te publiceren. De regel
vraagt geen opschoning van bestaande bestanden.

De programmeerregels gelden voor softwareontwikkeling in alle projecten en
omgevingen. Agents ondernemen geen cyberwerk waarvoor Daybreak of vergelijkbare
extra toegang nodig is en stoppen bij een blokkade, zonder omweg of voorstel om
toegang aan te vragen. Gewone veilige implementatie en regressietests blijven
onderdeel van het werk. Interfaces krijgen een bewuste visuele vormgeving;
Unicode-pijlen en driehoekjes als UI-iconen worden vervangen door passende SVG-
of CSS-vormen. Nieuwe UI sluit aan op de bestaande vormgeving; ontbreekt die,
dan wordt eerst een gedeelde design language vastgesteld. De hele applicatie
gebruikt dezelfde visuele en interactieafspraken. Interacties zoals uitklappen
krijgen korte, vloeiende animaties die de bediening niet vertragen, met respect
voor voorkeuren voor minder beweging. De regel geldt voor de UI die wordt
gemaakt of aangepast.

De globale onderhoudsregel laat agents actief letten op updates van Docker
images, Codex en andere tools, Git-repositories, projectafhankelijkheden en
systeempakketten.
Ze controleren relevante onderdelen gericht, hergebruiken recente bevindingen
en melden concrete verbeteringen met hun impact. Uitvoeren volgt de bestaande
autorisatie en de updateprocedure van het project of de omgeving. Dit legt geen
nieuwe periodieke systeemaudit vast.

Bij sessiestart controleert de agent de bronrepository van de gedeelde skills.
Voor taakgebonden repositories gebeurt dat voordat het werk erin begint. Een
schone checkout met de verwachte upstream, zonder eigen commits of gelijktijdig
werk, mag zelfstandig worden bijgewerkt met `git pull --ff-only`. Lokale
wijzigingen of afwijkende geschiedenis worden gemeld en behouden. Voor checkouts
waaruit een applicatie direct draait, geldt de projectprocedure voor updates of
deployment.

Voor ophalen op een andere machine is geen GitHub-account nodig:

```bash
git clone https://github.com/robelene112/agent-skills.git
```

Installatie in een agent wordt afzonderlijk gekozen. `.local/` bevat op de
oorspronkelijke VPS de persoonlijke en Odoo-varianten voor vergelijking en
wordt niet in Git opgenomen.

## Regels gebruiken op een andere machine

Gebruik hetzelfde script voor installatie en updates op Arch Linux, Ubuntu en
Windows 11 via WSL. Voer het op Windows uit **in WSL**. Vereisten zijn Python
3.9 of nieuwer, Git en, voor dit downloadcommando, curl. Er is geen persoonlijke
GitHub-login of sudo nodig voor de installatie zelf:

```bash
curl -fsSL https://raw.githubusercontent.com/robelene112/agent-skills/main/setup.py | python3 -
```

Dit maakt standaard `~/agent-skills` aan. Voor latere updates kan hetzelfde
commando worden gebruikt, of de lokale kopie:

```bash
python3 ~/agent-skills/setup.py
```

Het script haalt de bron bij met een fast-forward, koppelt de vijf persoonlijke
skills en alle stabiele Matt Pocock-skills aan `~/.agents/skills/` en werkt de
globale instructies bij. Nieuwe upstream skills krijgen een link; verwijderde
skills verliezen alleen hun door het script beheerde link. Andere skills blijven
staan. De Odoo-projectskill en het Saito-voorstel worden niet globaal geactiveerd.

WSL wordt automatisch herkend en krijgt ook `outlook-local`. Gewoon Linux krijgt
geen Outlook- of VPS-instructies. Kies op een VPS eenmalig het VPS-profiel om ook
de opslagverwijzing te activeren; volgende uitvoeringen onthouden die keuze:

```bash
python3 ~/agent-skills/setup.py --environment vps
```

`--environment linux` of `--environment wsl` wijzigt een eerder gekozen profiel.
`--repo-dir /pad/naar/agent-skills` kiest een andere broncheckout. Een bestaande
lokale scriptkopie gebruikt zijn eigen checkout. `--offline` past alleen een
bestaande bron toe zonder Git-update, bijvoorbeeld bij bewust lokaal onderhoud;
gebruik deze optie niet om een updateconflict stilzwijgend te omzeilen.

Bestaande instructies blijven buiten een herkenbaar beheerd blok behouden.
Codex' `CODEX_HOME` en een actief `AGENTS.override.md` worden gerespecteerd.
Oude Codex-skills onder `~/.codex/skills/` of je eigen `CODEX_HOME` met dezelfde
naam als een te installeren skill worden automatisch gemigreerd: de bestaande
map, het bestand of de link verhuist naar een unieke backupmap buiten de actieve
skills-mappen. Lokale aanpassingen blijven in die backup behouden. De installer
toont de locatie en bewaart haar in de installatiestatus. Codex' `.system/` en
skills die deze repository niet levert blijven op hun plek. Herhaald uitvoeren
maakt geen nieuwe backup zolang er geen nieuwe oude installatie bij is gekomen.

Andere skillconflicten worden vooraf gemeld zonder bestaande skills of
instructies te overschrijven. Een vuile broncheckout, eigen commits, afwijkende
upstream of mislukte fetch stopt de update. Het script bewaart installatiestatus,
backups en een proceslock onder
`${XDG_STATE_HOME:-~/.local/state}/agent-skills/`. De lock voorkomt twee
gelijktijdige uitvoeringen van dit script; voer het niet uit terwijl een andere
agent de broncheckout bewerkt.

Als `~/.claude/` bestaat, configureert het script ook Claude Code vanuit dezelfde
bron. `--claude` activeert dat ook bij een eerste installatie. Andere agents
moeten hun eigen vaste instructie-ingang gebruiken. Start na installatie een
nieuwe agentsessie om de globale instructies te laden. Zie de officiële uitleg
over [Codex-skills](https://learn.chatgpt.com/docs/build-skills),
[globale Codex-instructies](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
en [Claude-geheugen](https://code.claude.com/docs/en/memory).

De Outlook-skill wordt afzonderlijk geactiveerd in de Windows/WSL-omgeving met
klassiek Outlook. Zie [lokale Outlook-installatie](environments/windows-wsl/OUTLOOK.md).
De standaard omvat alle gekoppelde mailboxen en toegankelijke mailmappen,
inclusief spam en verwijderde items. Op WSL activeert de globale ingang de skill
bij sessiestart: agents lezen tijdens actieve sessies proactief nieuwe mail en
melden relevante acties, deadlines en urgentie. Voor projectwerk lezen zij eerst
vrijwel alle relevante correspondentie rond het project en de contactpersonen,
ook gelezen, verzonden en oudere berichten. Zoeken op `--participant` neemt zowel
afzender als ontvangers mee. Een lokale controlecursor voorkomt onnodig herhalen
van de algemene mailcheck; die is geen historische grens voor projectcontext.
Dit stelt geen timer of achtergrondtaak in. De helper leest en zoekt, controleert de
ongelezenstatus en herstelt die alleen wanneer een oorspronkelijk ongelezen
bericht tijdens het lezen toch als gelezen is gemarkeerd. Gewone leesacties
slaan niets op. De VPS-installatie krijgt deze lokale Windows-capaciteit niet.

GitHub haalt de Matt Pocock-updates automatisch op. Agents gebruiken bij
sessiestart het setup/update-script volgens `proactive-updates`, zodat naast
gewijzigde skillinhoud ook nieuwe links en globale instructies worden bijgewerkt.
Dit gebeurt tijdens een agentsessie; er is geen lokale timer ingericht. De
VPS-notitie hoort niet op de laptops geactiveerd te worden. De backups van oude
Codex-installaties blijven lokaal beschikbaar om eventuele persoonlijke
aanpassingen terug te vinden; ze worden niet naar GitHub gestuurd.

## Matt Pocock bijwerken

Iedere maandag om 05:23 UTC controleert GitHub Actions de stabiele skills op
upstream `main`. De officiële pluginmanifest bepaalt welke skills bij die set
horen. Nieuwe, gewijzigde en verwijderde skills worden gecontroleerd en direct
op `main` bijgewerkt. Hiervoor is geen wekelijkse bevestiging nodig. Ophalen
en activeren op een machine is een afzonderlijke stap. De eigen skills onder
`skills/` worden door de updater niet veranderd.

De workflow kan ook handmatig via GitHub Actions worden gestart. Voor lokale
controle en bijwerken:

```bash
python3 -m pip install -r requirements-dev.txt
python3 scripts/update-matt-pocock.py --check
python3 scripts/update-matt-pocock.py
```

De updater bewaart de upstream licentie en bronrevision, controleert metadata
en hashes, en weigert lokale aanpassingen aan de bestaande vendorbestanden.
Een upstream commit zonder gewijzigde skillbestanden maakt geen nieuwe commit.
De updatejob controleert de kandidaat voordat hij naar `main` wordt gepusht.
De push gebruikt de tijdelijke GitHub Actions-token; de updatejob levert de
verificatie voor deze automatische commit. Gewone pushes naar `main` en PR's
met wijzigingen buiten de vendormap krijgen de normale CI-controle.

Matt Pococks bestanden behouden hun [MIT-licentie](vendor/matt-pocock/LICENSE).
Zijn aanroepbeleid blijft behouden: workflowfasen worden op verzoek gestart;
herbruikbare disciplines mogen de agent ondersteunen wanneer de taak past.
