# Agent skills

Een openbare bronrepository voor persoonlijke skills en een gecontroleerde
kopie van Matt Pococks volledige stabiele skillset:
[robelene112/agent-skills](https://github.com/robelene112/agent-skills).
Deze repository vervangt nog geen geïnstalleerde skill.

| Onderdeel | Locatie | Status |
| --- | --- | --- |
| Persoonlijke ontwikkelwerkwijze | [dev-loop](skills/dev-loop/SKILL.md) | Herzien voorstel, nog niet geactiveerd |
| Saito-ontwikkeling | [saito-dev](skills/saito-dev/SKILL.md) | Herzien voorstel, nog niet geactiveerd |
| Matt Pocock | [Upstream skills](vendor/matt-pocock/skills/) | Ongewijzigde, gecontroleerde snapshot |
| Beoordeling van bestaande skills | [Review](docs/REVIEW.md) | Behouden, verplaatsen en vervangen onderbouwd |
| Bron en bestandscontrole | [source.json](vendor/matt-pocock/source.json) | Actuele bronrevision en SHA-256-hashes |

De eigen skills zijn voorstellen voor een volgende versie. De huidige globale
skills, Odoo BI-ingangen en Red Square-projectregels blijven actief zoals ze
waren. In het bijzonder verandert deze repository de afspraak over opeenvolgende
Red Square-tickets niet.

`dev-loop` koppelt Matt Pococks fasen automatisch aan elkaar: na de grill volgen
specificatie, tickets, implementatie, review met herstel en retro. De agent kiest
zelf testaanpak en ticketverdeling binnen de afgesproken scope. Er is geen
goedkeuring per fase of ticket nodig; nieuwe productkeuzes buiten die scope
gaan terug naar de gebruiker. Parallelle implementatie volgt de mogelijkheden
en regels van het project. Een verzoek om alleen een grill of andere losse fase
blijft tot die fase beperkt. `saito-dev` houdt Saito-specifieke beslisregels bij
elkaar en laadt operationele details alleen wanneer nodig.

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
`dev-loop` bundelt het verzoek om de hele keten zelfstandig af te werken.
Herbruikbare disciplines mogen de agent ondersteunen wanneer de taak past.
