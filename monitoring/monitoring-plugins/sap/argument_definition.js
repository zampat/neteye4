/* ICINGA DSL Script that fills a parameter with the format desired by the client
 *
 * 1. It gets the service
 * 2. It gets from the service all variables that begins with a case-insensitive prefix (e.g., "SAP_KPI_")
 * 3. It extracts the parameter name (key) for "SAPRFC", e.g., sap_kpi_it_upper_threshold --> IT_UPPER_THRESHOLD
 * 4. It extracts the values corresponding to the keys, e.g., $service.vars.sap_kpi_it_upper_threshold"
 * 5. It builds the return query (depending on the different value types)
 *
 * It should be deployed in the command definition
 */
host_name = macro("$host.name$");
service_name = macro("$service.name$");
pattern = "SAP_KPI_";
// Extract exactly this service in variable s
var my_filter = function(s) use(host_name, service_name) { s.name == service_name && s.host_name == host_name }
s = get_objects(Service).filter(my_filter)[0];
// extract all variables that begins with sap_kpi_<SAP_VARIABLE>, e.g., sap_kpi_it_upper_threshold
sap_kpi_parameters = s.vars.keys().filter(v => v.upper().find("SAP_KPI_") == 0);
// extract <SAP_VARIABLE> --> IT_UPPER_THRESHOLD
sap_kpi_keys = sap_kpi_parameters.map(x => x.upper().replace("SAP_KPI_", ""));
// extract the value of the variables
var my_fun = function(x) use(s) { s.vars[x] }
sap_kpi_values = sap_kpi_parameters.map(my_fun);
//
result = "";
for (i in range(0, len(sap_kpi_parameters))) {
    key = sap_kpi_keys[i];
    value = sap_kpi_values[i];
    value_type = typeof(value).name;
    if (value_type == "String" || value_type == "Number") {
        result = result + key + "=" + value.to_string() + "; ";
    } else if (value_type == "Boolean") {
        if (value) {
            result = result +  key + "=X; ";
        } else {
            result = result +  key + "=; ";
        }
    } else if (value_type == "Array") {
        result = key + "=";
        for (x in range(0, len(value) - 1)) {
            result = result + value[x].to_string() + ",";
        }
        result = result + value[len(value) - 1].to_string() + "; ";
    } else {
        log(key + " " + typeof(value).name + " Not yet supported ");
    }
}
return result;
