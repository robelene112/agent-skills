# Eerste beoordeling van de persoonlijke skills

Beoordeling van 14 oktober 2026. De oorspronkelijke bestanden staan lokaal in
`.local/imports/`, met hashes in `.local/imports.json`. De voorstellen onder
`skills/` zijn nog niet in een agentinstallatie geactiveerd.

## Dev-loop

Er zijn drie verschillende ingangen met dezelfde naam:

| Variant | Beoordeling |
| --- | --- |
| Globale dev-loop | Algemene workflow met bruikbare oriëntatie, gebruikersperspectief en verificatie; schrijft ook overal eigen PRD-conventies en één increment tegelijk voor |
| Odoo BI-dev-loop | Korte lokale ingang naar de onderhouden Odoo-workflow; bewust projectgebonden en te behouden |
| Dev-loop in de Odoo-broncheckout | Oude laptopworkflow met inmiddels onjuiste runtime-, test- en data-afspraken |

De oude Odoo-bronvariant veronderstelt `custom_modules/odoo_bi`, een laptopvenv
en `./odoo_bi.sh`. Hij laat de gebruiker tests uitvoeren, splitst standaard UI
en backend, richt op 150 tot 300 regels en behandelt data als wegwerpbaar. De
huidige Odoo-projectregels gebruiken de VPS-helper, een behouden database en
verifieerbare verticale slices. Deze oude variant is geen geschikte algemene
bron voor de nieuwe repository.

### Behouden in het voorstel

- Oriënteren op de werkelijke checkout, actuele code, gebruikerswijzigingen en
  toepasselijke projectregels.
- Repositoryfeiten zelf onderzoeken en bestaande beslissingen hergebruiken.
- Werk afbakenen met een controleerbaar resultaat en passende verificatie.
- Gebruikersfrictie serieus nemen bij productkeuzes; dit staat nu in een
  afzonderlijke referentie voor werk aan gebruikersflows.
- Overdracht en status baseren op bewijs, met onderscheid tussen code,
  productacceptatie en deployment.

### Vervangen of projectgebonden maken

- De tweede eigen grill/PRD/increment-methodiek wordt een korte ingang naar de
  geselecteerde projectworkflow en Matt Pococks skills.
- Documentpaden, commitregels, runtimecommando's en afrondingsconventies horen
  bij het project.
- Eén increment tegelijk wordt geen universele beperking. `Next inc` blijft
  één gevraagd onderdeel; parallel werk volgt de gekozen werkwijze en de
  toepasselijke projectbeperkingen.
- Herhaalde goedkeuring na een implementatieverzoek wordt vermeden; bestaande
  autorisatie en werkelijk nieuwe externe handelingen blijven onderscheiden.

### Besluit tijdens de herziening

De gebruiker wil na de grill zelfstandig laten doorwerken: `to-spec`,
`to-tickets`, implementatie, review met herstel en retro. De oude rol met
handmatige review per increment en een eigen planningsmethodiek vervalt.

De toegevoegde waarde van `dev-loop` is nu uitsluitend het koppelen en hervatten
van deze fasen. Matt Pocock blijft de inhoudelijke bron. Zijn `to-spec` vraagt
om bevestiging van testseams en `to-tickets` om goedkeuring van ticketverdeling;
in deze persoonlijke workflow zijn die technische keuzes aan de agent
gedelegeerd. De upstream bestanden blijven ongewijzigd.

`implement-spec` is de route voor nuttige, toegestane parallelle uitvoering;
anders rondt `implement` het afgesproken werk opeenvolgend af. De review die
beide implementatieskills al aanroepen wordt hergebruikt. Een losse opdracht
voor één fase blijft beperkt tot die fase. Nieuwe productkeuzes buiten de
afgesproken scope gaan terug naar de gebruiker. Er is nog geen installatie
uitgevoerd en bestaande projectworkflows zijn nog niet aangepast.

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
