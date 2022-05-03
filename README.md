# Intezer EDR Connect
Automate EDR alert triage with incident file scanning by Intezer.

To tackle the alert fatigue most security teams experience, we have developed Intezer EDR Connect to provide you with a lightweight and simple way to automate EDR alert triage. We use [Intezer](https://www.intezer.com/) to enrich file-based alerts in your EDR and accelerate the investigation and prioritization processes.
Intezer analyzes files using both static and dynamic techniques. It detonates the file in a sandbox, extracts memory modules, and compares the extracted code against an extensive genome database. Intezer’s unique code reuse detection technology allows you to determine the file verdict and its [classification and origin](https://analyze.intezer.com/files/7e840af1a1cac73a67f9b3e22563161feb6d16a529189e776f6661ba84d4c34c).

![Emotet-analysis](https://user-images.githubusercontent.com/63956508/156149639-dee9f94d-e5a7-48f4-82f4-6e4e5c96b8e2.png)



The app is cautious about quota consumption and is configurable in that regard (config).
When the same file triggers multiple incidents, the connector analyzes the file once, reducing one scan from the quota, and will enrich all incidents.
Intezer EDR Connect only supports enterprise and trial Intezer users

# How Does it Work?
The connector fetches new file-based alerts from your EDR and sends them to analysis in Intezer. Then, the connector pushes the analysis result to the EDR as an incident note.

<img width="627" alt="Screen Shot 2022-02-27 at 13 07 00" src="https://user-images.githubusercontent.com/63956508/155879931-ba318f1d-5381-4008-8245-ce33513ef7a1.png">

## Examples
Example of an enriched incident in [SentinelOne](https://www.sentinelone.com/).

<img width="693" alt="Screen Shot 2022-02-27 at 13 08 01" src="https://user-images.githubusercontent.com/63956508/155879972-f5ec9fed-04d2-4b1c-8f57-a826c8f58e92.png">

# Quick Start
Intezer EDR Connect deployment can be managed by Intezer or set up with Docker or Kubernetes.

## Managed by Intezer
Intezer can host EDR Connect for enterprise users. To set it up, please get in touch with our [support](support@intezer.com).

## Set up with Docker
1. Create a working directory: ```mkdir intezer-edr-connect ```
2. Pull the docker image: ```docker pull intezer/edr-connect ```
3. Copy the [config](config.yaml) file to your working directory (intezer-edr-connect, name it config.yaml)
4. Change the config settings
5. Run: ```docker run -v $(pwd)/config.yaml:/code/config/config.yaml intezer/edr-connect ```


https://user-images.githubusercontent.com/63956508/155881445-8277286f-cbcd-4a09-9cae-c51075cfcbf4.mov




## Set up with Kubernetes
You can use our Kubernetes deployment [file template](deployment-edr-connect.yaml).
1. Replace the <nodepool> placeholder with your desired node pool.
2. Create a new namespace called intezer-edr-connect
```bash
kubectl create namespace intezer-edr-connect
```
  
# Monitoring
We advise adding health check monitoring to ensure that the service is up and running.
See [Grafana monitoring example](grafana_query.json).

# Supported EDRs
* SentinelOne
* CrowdStrike
* Microsoft Defender (coming soon)
* Carbon Black (coming soon)
* Cortex XDR (coming soon)

# Upcoming Features
* **Automated incident endpoint scanning**: When a new memory-based incident occurs, Intezer EDR Connect scans the endpoint and pushes the result back to the EDR.
* **Incident tagging and prioritization**: Intezer EDR Connect provides relevant tags and a risk score to support prioritization
* **Automated triage action**: Provide the ability to set an “automation policy” to take actions based on Intezer’s results (e.g. change incident priority, quarantine the machine, mark the incident as FP, ...)
* **EDR advanced response queries**: Get EDR specific queries (based on IOCs, detection opps, and YARA) to search for infections and other variants directly in your EDR.
