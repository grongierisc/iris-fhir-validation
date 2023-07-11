import iris
import json
from iris_dollar_list import DollarList

def list_of_packages():
    packages = iris.cls('HS.FHIRMeta.Storage.Package').GetAllPackages()
    # loop through packages as an iris list
    for i in range(1, packages.Count()):
        # pass in a reference to a json object
        my_json = iris.ref(None)
        # call the _JSONExportToString method on the package
        packages.GetAt(i)._JSONExportToString(my_json)
        # convert the json string to a python dictionary
        dikt = json.loads(my_json.value)
        # print the dictionary as pretty json
        print(json.dumps(dikt, indent=4, sort_keys=True))

def import_package(paths_to_packages):
    iris_list = DollarList()
    for path in paths_to_packages:
        iris_list.append(path)
    iris.cls('HS.FHIRMeta.Load.NpmLoader').importPackages(iris_list.to_bytes())

def delete_package(package_name):
    iris.cls('HS.FHIRMeta.Load.NpmLoader').UninstallPackage(package_name)

def add_package_to_endpoint(endpoint_name,packages_names):
    # get the endpoint
    instance_key = iris.cls('HS.FHIRServer.API.InteractionsStrategy').GetStrategyForEndpoint(endpoint_name).InstanceKey
    # add the packages to the endpoint
    list_package = DollarList()
    for package_name in packages_names:
        list_package.append(package_name)
    iris.cls('HS.FHIRServer.Installer').AddPackagesToInstance(instance_key, list_package.to_bytes())
    print(f"\nPackages added to endpoint")

def list_package_of_endpoint(endpoint_name):
    # get the endpoint
    service = iris.cls('HS.FHIRServer.ServiceAdmin').GetInstanceForEndpoint(endpoint_name)
    print(DollarList().from_bytes(bytes(service.packageList,"utf-8")).to_list())

def index_endpoint(endpoint_name):
    iris.cls('HS.FHIRServer.Storage.Json.Tools.Index').upgradeServiceMetadata(endpoint_name)

def update_capability_statement(endpoint_name,json_file):
    strategy = iris.cls('HS.FHIRServer.API.InteractionsStrategy').GetStrategyForEndpoint("/fhir/ror")
    interactions = strategy.NewInteractionsInstance()
    newCapabilityStatement = iris.cls('%Library.DynamicObject')._FromJSONFile("/irisdev/app/data/ans.fhir.fr.ror/CapabilityStatement-ror-serveur.json")
    interactions.SetMetadata(newCapabilityStatement)

if __name__ == '__main__':
    # create a simple command line interface
    import argparse
    parser = argparse.ArgumentParser(description='FHIR Package Manager')
    parser.add_argument('--list', action='store_true', help='List all packages')
    parser.add_argument('--imports', nargs='+', help='Import packages')
    parser.add_argument('--delete', nargs='+', help='Delete packages')
    parser.add_argument('--add', nargs='+', help='Add packages to endpoint, first argument is endpoint name, the rest are packages')
    parser.add_argument('--list-endpoint', action='store_true', help='List packages of endpoint')
    parser.add_argument('--index', nargs='+', help='Index endpoint')
    parser.add_argument('--update-capability-statement', nargs='+', help='Update capability statement of endpoint')

    args = parser.parse_args()

    if args.list:
        list_of_packages()
    elif args.imports:
        import_package(args.imports)
    elif args.delete:
        for package in args.delete:
            delete_package(package)
    elif args.add:
        add_package_to_endpoint(args.add[0], args.add[1:])
    elif args.list_endpoint:
        list_package_of_endpoint(args.list_endpoint)
    elif args.index:
        for endpoint in args.index:
            index_endpoint(endpoint)
    elif args.update_capability_statement:
        update_capability_statement(args.update_capability_statement[0],args.update_capability_statement[1])
    else:
        parser.print_help()


