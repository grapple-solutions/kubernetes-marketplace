# Verify your grapple-solution-framework deployment

## get further details about how to use the grapple resources:
Installing the grapple solution framework may take a couple of minutes.
While waiting, you can explore the CRDs that have been installed for you in your cluster.
```
kubectl explain grapi --recursive # for the grapple instant API
kubectl explain gruim --recursive # for the grapple UI modules
kubectl explain gras --recursive # for the grapple ApplicationSet
```

## verify the completion of the installation
In order to verify the completion, you can run the following command:
```
kubectl wait -n grpl-system configurations grpl --for condition=Healthy=True --timeout=300s
```

The deployment of the test case may also take some minutes.
You can verify the completion of the installation of the test case with the following commands:
```
kubectl wait deployment -n grpl-test grpl-test-grpl-test-grapi grpl-test-grpl-test-gruim --for condition=Available=True --timeout=600s
```


## verify the deployment of the grapple resources in your cluster (the package comes with a test case for illustration purpose)
Run the following command to get details about the deployed custom resources of the test case
```
kubectl get gras,grapi,gruim -A
```


## see the functionality of the deployed test case

### for the automatically generated grapple instant API
```
kubectl get ing -n grpl-test -l app.kubernetes.io/name=grapi -o custom-columns=HOST:..host
```
And check the generated api in the browser

example link:
```
http://<yourNS>-<yourGrapiName>-grapi.<yourDNS>.grapple-demo.com/customers?filter={"limit":100,"include":["employees"]}
```


### and for the automatically generated grapple UI modules
```
kubectl get ing -n grpl-test -l app.kubernetes.io/name=gruim -o custom-columns=HOST:..host
```
And check the generated ui modules in the browser


# next steps

## try with your own data source
First, you have to make sure, that the database is reachable from the cluster.
Let's assume we use a mysql database in AWS RDS.
Then please run the following commands:
(Please replace the <your_...> with your values before running the command)
```
export DBHOST=<your_aws_rds_instance>.<your_aws_region>.rds.amazonaws.com
export DBUSER=<your_db_user>
export DBPW=<your_db_pw>
export DBSCHEMA=<your_db_schema>

kubectl apply -f - <<EOF
apiVersion: grsf.grpl.io/v1alpha1
kind: GrappleApplicationSet
metadata:
  name: mygras
spec:
    name: mygras
    grapis:
      - name: mygrapi
        spec:
            beimagetag: "v0.112"
            discoveredrepos: true
            datasources:
            - name: "mydb"
              spec:
                mysql:
                    name: "mydb"
                    url: ""
                    host: "${DBHOST}"
                    port: "3306"
                    user: "${DBUSER}"
                    password: "${DBPW}"
                    database: "${DBSCHEMA}"
            discoveries:
            spec:
            - name: "mydbdisc"
              spec:
                dataSource: "mydb"
                schema: "${DBSCHEMA}"
                all: true
                disableCamelCase: false
            # relations:
            # - name: "employees"
            #   spec:
            #     relationName: "employees"
            #     sourceModel: "Customers"
            #     destinationModel: "Employees"
            #     foreignKeyName: "employeesId"
            #     relationType: "belongsTo"
            #     registerInclusionResolver: true
            restcruds:
            - name: "mydbrc"
              spec:
                datasource: "mydb"
    gruims:
      - name: mygruim
        spec:
            uiimagetag: "0.1.34"
            style: '{"colors":{"primary":{"DEFAULT":"#34344A","fg":"#fff"},"accent":{"DEFAULT":"#CC5A71","fg":"#fff"}}}'
            config: ""
            additionalpackages: ""
EOF

```



# conclusion
Is this interesting? Do you want to see more?
the grapple solution framework is highly customizable and integratable to your environment.

If you want to learn more, please don't hesitate to contact us:

Website:
[https://grapple-solutions.com](https://grapple-solutions.com)
Email:
[info@grapple-solutions.com](mailto:info@grapple-solutions.com)



# legal
Todo: add legal stuff