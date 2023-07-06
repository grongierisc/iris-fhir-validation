from FhirInteraction import Interaction

class CustomInteraction(Interaction):

    def on_before_request(self, fhir_service, fhir_request, body, timeout):
        if body:
            print(f"on_before_request : {body['id']}")

    def on_after_request(self, fhir_service, fhir_request, fhir_response, body):
        print(f"on_after_request : {body}")

    def post_process_read(self, fhir_object):
        print(f"post_process_read: {fhir_object}")
        return False

    def post_process_search(self, rs, resource_type):
        print(f"post_process_search: {rs}")
        return True