# Agent skills

Een openbare bronrepository voor persoonlijke skills en een gecontroleerde
kopie van Matt Pococks volledige stabiele skillset:
[robelene112/agent-skills](https://github.com/robelene112/agent-skills).

| Onderdeel | Locatie | Status |
| --- | --- | --- |
| Saito-ontwikkeling | [saito-dev](skills/saito-dev/SKILL.md) | Herzien voorstel, nog niet geactiveerd |
| Odoo 20-frameworkkennis | [odoo-20](skills/odoo-20/SKILL.md) | Geïnstalleerd in het Odoo BI-project |
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

Voor ophalen op een andere machine is geen GitHub-account nodig:

```bash
git clone https://github.com/robelene112/agent-skills.git
```

Installatie in een agent wordt afzonderlijk gekozen. `.local/` bevat op de
oorspronkelijke VPS de persoonlijke en Odoo-varianten voor vergelijking en
wordt niet in Git opgenomen.

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
