# iris-fhir-validation

## Example of request

```http
GET http://localhost:8083/fhir/r4/metadata
Accept: application/json+fhir
```

### SearchParams

```http
GET http://localhost:8083/fhir/r4/SearchParameter
Content-Type: application/json+fhir
Accept: application/json+fhir
```

```http
GET http://localhost:8083/fhir/r4/Patient?name=elbert
Content-Type: application/json+fhir
Accept: application/json+fhir
```

## Reloader

```objectscript
set endpoint = "/fhir/r4"
set strategy = ##class(HS.FHIRServer.API.InteractionsStrategy).GetStrategyForEndpoint(endpoint)
set interactions = strategy.NewInteractionsInstance()
d interactions.SetMetadata( strategy.GetMetadataResource() )
zw $system.external.stopServer("%Java Server")
```

```http
GET http://localhost:8083/fhir/r4/$restart
Accept: application/json+fhir
```

### validate patient

```http
POST http://localhost:8083/fhir/r4/Patient/
Content-Type: application/json+fhir
Accept: application/json+fhir
Prefer: return=representation

{
  "resourceType": "Patient",
  "id": "PatientExample",
  "meta": {
    "profile": [
      "http://example.org/StructureDefinition/MyPatient"
    ]
  },
  "extension": [
    {
      "url": "http://example.org/StructureDefinition/birthsex-extension",
      "valueCode": "M"
    },
    {
      "url": "http://isc.demo/fhir/StructureDefinition/patient-FavoriteColor-extension",
      "valueString" : "Blue"
    }
  ],
  "name": [
    {
      "given": [
        "Janette"
      ],
      "family": "Smith"
    }
  ],
  "maritalStatus": {
    "coding": [
      {
        "code": "M",
        "system": "http://terminology.hl7.org/CodeSystem/v3-MaritalStatus",
        "display": "Married"
      }
    ]
  }
}

```