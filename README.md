# Regula Document Reader Java Client
#===============================================================================
# DocumentReader Web Java Client
#===============================================================================
# Original Author: Regula Forensics Inc.
# Dev Container Implementation: Dean Luus
# Email: dean.luus@jdconsulting.com
# GitHub: https://github.com/DeanLuus
# Date: 2025/03/27
# Last updated: 2025/03/27
#===============================================================================

[![maven](https://img.shields.io/maven-metadata/v?metadataUrl=https%3A%2F%2Fmaven.regulaforensics.com%2FRegulaDocumentReaderWebClient%2Fcom%2Fregula%2Fdocumentreader%2Fwebclient%2Fmaven-metadata.xml&style=flat-square)](https://support.regulaforensics.com/hc/en-us/articles/115000916306-Documentation)
[![OpenAPI](https://img.shields.io/badge/OpenAPI-defs-8c0a56?style=flat-square)](https://github.com/regulaforensics/DocumentReader-web-openapi)
[![documentation](https://img.shields.io/badge/docs-en-f6858d?style=flat-square)](https://support.regulaforensics.com/hc/en-us/articles/115000916306-Documentation)
[![live](https://img.shields.io/badge/live-demo-0a8c42?style=flat-square)](https://api.regulaforensics.com/)

Java client for Regula Document Reader Web API compatible with JVM and Android.

:bulb: Before you start: if you want to try an online demo, visit our [playground](https://api.regulaforensics.com).

:warning: NOTE: If a custom Document Reader endpoint is not specified, demo web API will be used by default.
By sending requests to demo Regula Document Reader web API, 
you agree with our [Privacy Policy](https://regulaforensics.com/en/company/privacy/) 
and [License Agreement](https://downloads.regulaforensics.com/work/SDK/doc/Eula.pdf).

## Installation

### Gradle

```gradle
repositories {
    maven {
        url = uri("https://maven.regulaforensics.com/RegulaDocumentReaderWebClient")
    }
}

dependencies {
    implementation("com.regula.documentreader:webclient:5.+")
}
```

### Maven

```xml
<repositories>
    <repository>
        <id>regula-documentreader</id>
        <url>https://maven.regulaforensics.com/RegulaDocumentReaderWebClient</url>
    </repository>
</repositories>

<dependencies>
    <dependency>
        <groupId>com.regula.documentreader</groupId>
        <artifactId>webclient</artifactId>
        <version>5.1.0</version>
    </dependency>
</dependencies>
```

## Usage Example

### Performing request

```java
byte[] imageBytes = readFile("australia_passport.jpg");
var image = new ProcessRequestImage(imageBytes, Light.WHITE);

var requestParams = new RecognitionParams()
        .withScenario(Scenario.FULL_PROCESS)
        .withResultTypeOutput(Result.STATUS, Result.TEXT, Result.IMAGES);

RecognitionRequest request = new RecognitionRequest(requestParams, List.of(image));

var api = new DocumentReaderApi();
RecognitionResponse response = api.process(request);
```

### Parsing results

```java
var status = response.status();
var docOverallStatus = status.getComplete() == CheckResult.OK ? "valid" : "not valid";
var docOpticalTextStatus = status.getDetailsOptical().getText();

var docNumberField = response.text().getField(DOCUMENT_NUMBER);
var docNumberMrz = docNumberField.getValue(Source.MRZ);
var docNumberMrzValidity = docNumberField.sourceValidity(Source.MRZ);
var docNumberMrzVisualMatching = docNumberField.crossSourceComparison(Source.MRZ, Source.VISUAL);
```

## Running the Example Project

Requirements:
- Java 11+

Verify your Java version:
```bash
java --version  
>  openjdk 14.0.1 2020-04-14
```

### With Demo API

Run the example using the demo endpoint:
```bash
./gradlew :example:run
```

### With Local API installation

Get your [free trial here](https://mobile.regulaforensics.com/). When you receive the `regula.license` file, 
copy it to the resources folder.

Follow [the instructions](https://docs.regulaforensics.com/develop/doc-reader-sdk/web-service/) to run Regula Document Reader web API locally.
Then run the example with your local endpoint:

```bash
API_BASE_PATH="http://127.0.0.1:8080" ./gradlew :example:run
```

### Example Output

```text
---------------------------------------------------------------------------
               Document Overall Status: not valid
                Document Number Visual: U0996738
                   Document Number MRZ: U0996738
    Validity Of Document Number Visual: 1
       Validity Of Document Number MRZ: 1
          MRZ-Visual values comparison: 1
---------------------------------------------------------------------------
```

The example also saves portrait and document image to your project.
You can modify the example code 
to get your own results.

## Development

Java client is written using Java 7 for compatibility. Development environment requires Java 11+.
Models generation is based on [OpenAPI specifications](https://github.com/regulaforensics/DocumentReader-web-openapi).

### Building from Source

1. Clone this repository
2. Build the project:
   ```bash
   ./gradlew build
   ```

### Dev Container

This project includes a dev container configuration for easy development environment setup:

1. Open in VS Code with Remote Containers extension
2. VS Code will automatically build and start the container
3. Models will be generated and the project will be built automatically

### Model Generation

The OpenAPI models are automatically generated using the OpenAPI generator. The process:

1. Uses the OpenAPI definitions from the openapi directory
2. Generates Java models and API clients
3. Applies enum mappings for proper type handling
4. Formats the generated code

### Contributing

If you have any problems with or questions about this client, please contact us
through a [GitHub issue](https://github.com/regulaforensics/DocumentReader-api-java-client/issues).

You are invited to contribute [new features, fixes, or updates](https://github.com/regulaforensics/DocumentReader-api-java-clien/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22), large or small.
We are always thrilled to receive pull requests, and do our best to process them as fast as we can.
