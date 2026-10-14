# Agent skills

Een openbare bronrepository voor persoonlijke skills en een gecontroleerde
kopie van Matt Pococks volledige stabiele skillset:
[robelene112/agent-skills](https://github.com/robelene112/agent-skills).

| Onderdeel | Locatie | Status |
| --- | --- | --- |
| Saito-ontwikkeling | [saito-dev](skills/saito-dev/SKILL.md) | Herzien voorstel, nog niet geactiveerd |
| Odoo 20-frameworkkennis | [odoo-20](skills/odoo-20/SKILL.md) | Geïnstalleerd in het Odoo BI-project |
| Globale communicatieregels | [global-communication](skills/global-communication/SKILL.md) | Geen em dashes; vragen in de chat |
| Tracker voor ontwikkeling | [github-issues](skills/github-issues/SKILL.md) | Nieuwe tickets en trackerspecificaties zijn GitHub Issues |
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

De globale onderhoudsregel laat agents actief letten op updates van Docker
images, Codex en andere tools, projectafhankelijkheden en systeempakketten.
Ze controleren relevante onderdelen gericht, hergebruiken recente bevindingen
en melden concrete verbeteringen met hun impact. Uitvoeren volgt de bestaande
autorisatie en de updateprocedure van het project of de omgeving. Dit legt geen
nieuwe periodieke systeemaudit vast.

Voor ophalen op een andere machine is geen GitHub-account nodig:

```bash
git clone https://github.com/robelene112/agent-skills.git
```

Installatie in een agent wordt afzonderlijk gekozen. `.local/` bevat op de
oorspronkelijke VPS de persoonlijke en Odoo-varianten voor vergelijking en
wordt niet in Git opgenomen.

## Regels gebruiken op een andere machine

Koppel of kopieer `skills/global-communication/`, `skills/github-issues/` en
`skills/proactive-updates/` naar `~/.agents/skills/`. Plaats de inhoud van
[de globale ingang](instructions/global/AGENTS.md) in Codex' `~/.codex/AGENTS.md`
(of de `AGENTS.md` in je eigen `CODEX_HOME`). Behoud eventuele bestaande
persoonlijke instructies. De ingang verwijst naar dezelfde skills op iedere
machine. Codex ondersteunt persoonlijke skills en links naar skillmappen;
zie [skills](https://learn.chatgpt.com/docs/build-skills) en
[globale instructies](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

Claude Code kan dezelfde ingang laden vanuit `~/.claude/CLAUDE.md`; zie
[Claude-geheugen](https://code.claude.com/docs/en/memory). Andere agents moeten
dezelfde regels vanuit hun eigen vaste instructie-ingang lezen. Start een nieuwe
sessie om de nieuwe globale ingang te laden. Op de VPS zijn de drie persoonlijke
skills gekoppeld en ingangen ingesteld; de bestaande projectrouting blijft
behouden.

Bij links naar deze bronrepository werkt een `git pull --ff-only` de skillinhoud
bij. Een gekopieerde skill moet na een bronupdate opnieuw gekopieerd worden.
Neem een gewijzigde globale ingang ook over in je persoonlijke instructiebestand.
GitHub haalt de Matt Pocock-updates automatisch op; lokale checkouts hebben nog
geen automatische pull. De VPS-notitie hoort niet op de laptops geactiveerd te
worden.

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
