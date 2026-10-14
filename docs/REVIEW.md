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
bronrepository. Zij blijven door hun bestaande distributie beheerd. De oude
Odoo 19-referenties en de lokale to-prd-compatibiliteitsingang zijn nog niet
gewijzigd.
