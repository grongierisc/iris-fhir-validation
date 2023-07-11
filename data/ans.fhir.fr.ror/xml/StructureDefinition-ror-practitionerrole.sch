<?xml version="1.0" encoding="UTF-8"?>
<sch:schema xmlns:sch="http://purl.oclc.org/dsdl/schematron" queryBinding="xslt2">
  <sch:ns prefix="f" uri="http://hl7.org/fhir"/>
  <sch:ns prefix="h" uri="http://www.w3.org/1999/xhtml"/>
  <!-- 
    This file contains just the constraints for the profile PractitionerRole
    It includes the base constraints for the resource as well.
    Because of the way that schematrons and containment work, 
    you may need to use this schematron fragment to build a, 
    single schematron that validates contained resources (if you have any) 
  -->
  <sch:pattern>
    <sch:title>f:PractitionerRole</sch:title>
    <sch:rule context="f:PractitionerRole">
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-practitionerrole-unit-exercise-mode']) &gt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-practitionerrole-unit-exercise-mode': minimum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-practitionerrole-unit-exercise-mode']) &lt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-practitionerrole-unit-exercise-mode': maximum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/RORPractitionerRoleName']) &lt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/RORPractitionerRoleName': maximum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://apifhir.annuaire.sante.fr/ws-sync/exposed/structuredefinition/practitionerRole-contracted']) &lt;= 1">extension with URL = 'https://apifhir.annuaire.sante.fr/ws-sync/exposed/structuredefinition/practitionerRole-contracted': maximum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://apifhir.annuaire.sante.fr/ws-sync/exposed/structuredefinition/practitionerRole-hasCAS']) &lt;= 1">extension with URL = 'https://apifhir.annuaire.sante.fr/ws-sync/exposed/structuredefinition/practitionerRole-hasCAS': maximum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://apifhir.annuaire.sante.fr/ws-sync/exposed/structuredefinition/practitionerRole-vitaleAccepted']) &lt;= 1">extension with URL = 'https://apifhir.annuaire.sante.fr/ws-sync/exposed/structuredefinition/practitionerRole-vitaleAccepted': maximum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-meta-creation-date']) &gt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-meta-creation-date': minimum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-meta-creation-date']) &lt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-meta-creation-date': maximum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-meta-comment']) &lt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-meta-comment': maximum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:identifier) &lt;= 1">identifier: maximum cardinality of 'identifier' is 1</sch:assert>
      <sch:assert test="count(f:practitioner) &gt;= 1">practitioner: minimum cardinality of 'practitioner' is 1</sch:assert>
      <sch:assert test="count(f:code) &gt;= 1">code: minimum cardinality of 'code' is 1</sch:assert>
      <sch:assert test="count(f:code) &lt;= 1">code: maximum cardinality of 'code' is 1</sch:assert>
      <sch:assert test="count(f:healthcareService) &gt;= 1">healthcareService: minimum cardinality of 'healthcareService' is 1</sch:assert>
      <sch:assert test="count(f:healthcareService) &lt;= 1">healthcareService: maximum cardinality of 'healthcareService' is 1</sch:assert>
      <sch:assert test="count(f:telecom) &lt;= 1">telecom: maximum cardinality of 'telecom' is 1</sch:assert>
      <sch:assert test="count(f:availableTime) &lt;= 1">availableTime: maximum cardinality of 'availableTime' is 1</sch:assert>
    </sch:rule>
  </sch:pattern>
  <sch:pattern>
    <sch:title>f:PractitionerRole/f:meta</sch:title>
    <sch:rule context="f:PractitionerRole/f:meta">
      <sch:assert test="count(f:id) &lt;= 1">id: maximum cardinality of 'id' is 1</sch:assert>
      <sch:assert test="count(f:versionId) &lt;= 1">versionId: maximum cardinality of 'versionId' is 1</sch:assert>
      <sch:assert test="count(f:lastUpdated) &gt;= 1">lastUpdated: minimum cardinality of 'lastUpdated' is 1</sch:assert>
      <sch:assert test="count(f:lastUpdated) &lt;= 1">lastUpdated: maximum cardinality of 'lastUpdated' is 1</sch:assert>
      <sch:assert test="count(f:source) &lt;= 1">source: maximum cardinality of 'source' is 1</sch:assert>
    </sch:rule>
  </sch:pattern>
  <sch:pattern>
    <sch:title>f:PractitionerRole/f:extension</sch:title>
    <sch:rule context="f:PractitionerRole/f:extension">
      <sch:assert test="count(f:id) &lt;= 1">id: maximum cardinality of 'id' is 1</sch:assert>
      <sch:assert test="count(f:url) &gt;= 1">url: minimum cardinality of 'url' is 1</sch:assert>
      <sch:assert test="count(f:url) &lt;= 1">url: maximum cardinality of 'url' is 1</sch:assert>
    </sch:rule>
  </sch:pattern>
  <sch:pattern>
    <sch:title>f:PractitionerRole/f:telecom</sch:title>
    <sch:rule context="f:PractitionerRole/f:telecom">
      <sch:assert test="count(f:id) &lt;= 1">id: maximum cardinality of 'id' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-telecom-communication-channel']) &gt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-telecom-communication-channel': minimum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-telecom-communication-channel']) &lt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-telecom-communication-channel': maximum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-telecom-usage']) &lt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-telecom-usage': maximum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-telecom-confidentiality-level']) &gt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-telecom-confidentiality-level': minimum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-telecom-confidentiality-level']) &lt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-telecom-confidentiality-level': maximum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:system) &lt;= 1">system: maximum cardinality of 'system' is 1</sch:assert>
      <sch:assert test="count(f:value) &gt;= 1">value: minimum cardinality of 'value' is 1</sch:assert>
      <sch:assert test="count(f:value) &lt;= 1">value: maximum cardinality of 'value' is 1</sch:assert>
      <sch:assert test="count(f:use) &lt;= 1">use: maximum cardinality of 'use' is 1</sch:assert>
      <sch:assert test="count(f:rank) &lt;= 1">rank: maximum cardinality of 'rank' is 1</sch:assert>
      <sch:assert test="count(f:period) &lt;= 1">period: maximum cardinality of 'period' is 1</sch:assert>
    </sch:rule>
  </sch:pattern>
  <sch:pattern>
    <sch:title>f:PractitionerRole/f:availableTime</sch:title>
    <sch:rule context="f:PractitionerRole/f:availableTime">
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-available-time-type-of-time']) &lt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-available-time-type-of-time': maximum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-available-time-effective-opening-closing-date']) &lt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-available-time-effective-opening-closing-date': maximum cardinality of 'extension' is 1</sch:assert>
      <sch:assert test="count(f:extension[@url = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-available-time-number-days-of-week']) &lt;= 1">extension with URL = 'https://interop.esante.gouv.fr/ig/fhir/ror/StructureDefinition/ror-available-time-number-days-of-week': maximum cardinality of 'extension' is 1</sch:assert>
    </sch:rule>
  </sch:pattern>
</sch:schema>
