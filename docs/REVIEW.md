# Eerste beoordeling van de persoonlijke skills

Beoordeling van 14 oktober 2026. De oorspronkelijke bestanden staan lokaal in
`.local/imports/`, met hashes in `.local/imports.json`. Het Saito-voorstel onder
`skills/` is nog niet in een agentinstallatie geactiveerd.

## Dev-loop

Op 14 oktober 2026 heeft de gebruiker gekozen om `dev-loop` geheel te verwijderen,
ook de lokale en oude varianten. De globale skill, het nieuwe voorstel in deze
repository, de Odoo BI-ingang, de Claude-link daarnaar en de oude laptopversie
in de Odoo-broncheckout zijn verwijderd.

De oude workflows bevatten eigen PRD-conventies, handmatige review per increment,
laptopcommando's en beperkingen die niet meer bij de gewenste werkwijze passen.
Ook het korte voorstel voor automatische fasecoördinatie vervalt: Matt Pococks
skills worden rechtstreeks gebruikt, met autonomie in de opdracht of
projectafspraken.

De voorkeur blijft om na een afgeronde grill zelfstandig specificatie, tickets,
implementatie en review met herstel af te werken. Technische keuzes over
testaanpak en ticketverdeling zijn dan gedelegeerd binnen de afgesproken scope.
Nieuwe productkeuzes buiten die scope gaan terug naar de gebruiker.

Actieve verwijzingen naar de verwijderde skill zijn bijgewerkt. Odoo gebruikt
rechtstreeks `docs/agents/development-workflow.md`. De runtime-, data- en
commitafspraken blijven in dat document. Matt Pococks bestanden zijn ongewijzigd.
Oorspronkelijke varianten blijven uitsluitend als niet-actieve imports onder
`.local/`; het verwijderde voorstel is terug te vinden in Git. Historische
migratieback-ups en oude gespreksdocumenten zijn geen actieve installaties.

## Saito-dev

De technische kern is nog bruikbaar: actuele checkout als API-bron, runtime-
grenzen, signeridentiteit, validatie, herhaalde aflevering, publieke payloads en
de levensduur van opgeslagen gegevens. Deze principes sluiten aan op de
gelezen Snake-bron: wallet signing/serialization, runtimeguards, een versie 2
scorepayload, de confirmationcallback en replayverificatie.

De oorspronkelijke skill bevat veel deployment- en migratielessen. Ze zijn
conditioneel nuttig, maar belasten ook iedere gewone modulewijziging. Het
voorstel zet ze achter één verwijzing en laat concrete omgevinggegevens in
de projecthandleiding. Het noemt native integratie waar protocolcompatibiliteit
dat relevant maakt en schrijft geen universele schema-aanpassing voor.

De bestaande modulechecklist blijft behouden. Daarin wordt een verplichte
payloadversie vervangen door een expliciete compatibilitystrategie, zodat een
kleine wijziging niet automatisch een nieuwe payloadversie vereist.

Dit is een beoordeling van instructies en gelezen broncode. Er is geen
live-node-, deployment- of protocolimplementatietest uitgevoerd.

### Toegevoegde waarde na het verwijderen van dev-loop

Advies: behoud een compacte Saito-domeinskill. Matt Pococks skills regelen de
ontwikkelwerkwijze; ze bevatten geen Saito-module-, transactie- of runtimekennis.
Die kennis is bruikbaar voor zowel Snake als andere Saito-integraties.

| Inhoud | Plaats |
| --- | --- |
| Saito-modulelifecycles, callbacks en browser/server/native grenzen | Domeinskill, met de actuele checkout als API-bron |
| Identiteit, ondertekening, ontvangstvalidatie, herhaling en publieke payloads | Domeinskill, toegepast op de veranderde grens |
| Consensusgegevens, archief, lokale indexes en herstelbaarheid | Domeinskill voor de keuze; concrete opslagafspraken in het project |
| Versiepins, paden, hostnamen, publishers en releasehistorie | Projectdocumentatie |
| Algemene planning, implementatiestappen, commitautorisatie en deploymentlessen | Geselecteerde workflow en projectafspraken |

Voorbeeld uit de huidige Snake-bron: `onConfirmation` gebruikt de signer,
normaliseert een replay en verifieert de run. Een ondertekende scoreclaim alleen
is onvoldoende. De runtimeguards en het gedeelde opslagadaptercontract zijn
andere concrete redenen om de domeinkennis te behouden.

De oude geïnstalleerde skill is inhoudelijk nog niet vervangen. Alleen de
verwijzing naar de verwijderde `dev-loop` is aangepast. Het compactere voorstel
in deze repository blijft beschikbaar voor verdere bespreking.

## Matt Pocock en bestaande projecten

Alle 27 stabiele skills uit de gecontroleerde Red Square-snapshot blijven
beschikbaar in `vendor/matt-pocock/skills/`. Hun 79 door het bronlock genoemde
bestanden zijn voor het kopiëren op SHA-256 gecontroleerd. De upstream licentie,
aanroepinstellingen en bronrevision zijn behouden.

De Odoo-selectie en de Red Square-selectie zijn nog niet vervangen. Odoo heeft
eigen runtime- en documentconventies en gebruikt oudere upstream details; Red
Square beperkt ticketimplementatie expliciet tot opeenvolgende uitvoering.
Dat onderscheid moet bij latere installatie en projectmigratie worden behouden
of bewust opnieuw worden gekozen.

OpenAI-systeemskills en connectorplugins vallen buiten deze persoonlijke
bronrepository. Zij blijven door hun bestaande distributie beheerd. De lokale
to-prd-compatibiliteitsingang is nog niet gewijzigd.

## Odoo 20

De gebruiker heeft de vervanging van Odoo 19 door Odoo 20 gevraagd, met uitsluitend
frameworkkennis. De nieuwe `skills/odoo-20/` bevat een korte ingang en vier
gerichte referenties: ORM/beveiliging, web/HTTP, moduledata/tests en primaire
bronlocaties. De 19 uitgebreide oude handleidingen zijn geen actieve kennisbron
meer. Er zijn geen grill-, PRD-, increment- of deploymentstappen toegevoegd.

De inhoud is gecontroleerd door bronnen in de draaiende build `20.0-20260926`
te lezen. De bestanden voor `ir.access`, de Owl-compatibiliteitslaag,
`ir.config_parameter` en table objects komen op SHA-256 overeen met officiële
commit `491e981505d28dfd85edea8ffb67bc8ed00826aa`. De overige beschreven grenzen
zijn tegen de huidige frameworkbestanden en bestaande projectimplementatie
bekeken. Dit is bronvalidatie, geen nieuwe runtime- of applicatietestrun.

De projectinstallatie staat in `.agents/skills/odoo-20/`; de Claude-installatie
linkt naar dezelfde map. De oude frameworkcheckout heeft eveneens een verwijzing
naar die installatie, zodat zijn vroegere `odoo19`-skill niet zelfstandig blijft
bestaan. Alle drie oude fysieke skillmappen zijn vooraf onder `.local/imports/`
bewaard en uit de actieve locaties verwijderd. Historische migratiegegevens
blijven historische gegevens.

Odoo BI-termen en ADRs blijven projectgebonden; testcommando's, databases en
runtimepaden blijven in de projecthandleiding. De persoonlijke bron en de
projectinstallatie zijn op identieke bestandsinhoud gecontroleerd. De gebruiker
vroeg vervolgens om deze eigen Odoo-projectwijzigingen te committen; ze zijn
vastgelegd in `d791c6a`, zonder de andere grill-handoff mee te nemen.

## Persoonlijke regels en omgeving

De gebruiker heeft drie expliciete regels vastgelegd. `global-communication`
bevat de globale communicatievoorkeuren: geen em dashes in uitgaande tekst en
vragen via de gewone chat, zodat antwoorden gedicteerd kunnen worden.
`github-issues` legt GitHub Issues vast als tracker voor ontwikkeling. Deze
persoonlijke regels wijzigen Matt Pococks upstream bestanden niet.

`instructions/global/AGENTS.md` is de vaste instructie-ingang naar die twee
skills. Op de VPS zijn de skills gekoppeld in `~/.agents/skills/`, met ingangen
voor Codex en Claude Code. Odoo en Snake gebruiken GitHub voor nieuwe tickets;
bestaande lokale plannen worden niet door deze instelling gemigreerd.
De bijgewerkte Odoo-trackerconfiguratie is gecommit in `132248f`.

De twee VPS-schijven zijn gecontroleerd tegen `lsblk`, `findmnt` en `df`:
`/dev/vda4` is `/`, en `/dev/vdb1` is `/mnt/storage`. Die machinefeiten staan
uitsluitend in `environments/vps/STORAGE.md`, met een gerichte verwijzing vanuit
de bestaande home-instructies.
