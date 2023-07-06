from FhirInteraction import Interaction

import iris


class CustomInteraction(Interaction):

    def on_before_request(self, fhir_service, fhir_request, timeout):
        print(f"on_before_request changes: {fhir_request.Json._Get('resourceType')}")

    def on_after_request(self, fhir_service, fhir_request, fhir_response):
        print(f"on_after_request : {fhir_response.Json._Get('resourceType')}")

    def post_process_read(self, fhir_object):
        print(f"post_process_read: {fhir_object}")
        return False

    def post_process_search(self, rs, resource_type):
        print(f"post_process_search: {rs}")
        return True