<#End to End Test
#one by one: 6hours , 12200 documents, 789mb.  Batch processing: 25 minutes 12238 documents 709.7mb (\\svrsa1fs03\library\)
powershell -ExecutionPolicy ByPass -command "C:\_AdminTools\Nova_Scripts\Search.Index.Elastic.ps1" -SharedFolders "\\svrsa1fs03\library\" -RecreateIndex 1
#one by one: ???.                              Batch processing: 13 hours 245761 documents 7.2gb (\\svrsa1fs03\fs\bus\  !do not use \\nova\files\Business Units\ it will multiply content by numberof projections == \\nova\nova-dfs\group\ )
powershell -ExecutionPolicy ByPass -command "C:\_AdminTools\Nova_Scripts\Search.Index.Elastic.ps1" -SharedFolders "\\svrsa1fs03\fs\bus\"
powershell -ExecutionPolicy ByPass -command "C:\_AdminTools\Nova_Scripts\Search.Index.Elastic.ps1" -SharedFolders "\\svradldb02\Exchange Integration Attachments\Travel_Invoices\Archive\"
powershell -ExecutionPolicy ByPass -command "C:\_AdminTools\Nova_Scripts\Search.Index.Elastic.ps1" -SharedFolders "\\svrsa1fs03\catalyst\Catalyst HRM\Fasttrack CVs 2016\"
powershell -ExecutionPolicy ByPass -command "C:\_AdminTools\Nova_Scripts\Search.Index.Elastic.ps1" -SharedFolders "\\svrsa1fs03\catalyst\Catalyst HRM\Fasttrack CVs 2015\"
powershell -ExecutionPolicy ByPass -command "C:\_AdminTools\Nova_Scripts\Search.Index.Elastic.ps1" -SharedFolders "\\svrsa1fs03\catalyst\Catalyst HRM\Fasttrack CVs 2014\"
powershell -ExecutionPolicy ByPass -command "C:\_AdminTools\Nova_Scripts\Search.Index.Elastic.ps1" -SharedFolders "\\svrsa1fs03\catalyst\Catalyst HRM\Fasttrack CVs 2013\"
#>


<#
Sphinx: craigslist.org
Solr: Cnet, Netflix, digg.com
Elasticsearch: Foursquare, Github, Amazone, Netsuite, AzureSearch

Phrases
-------
1.Sometimes the fastest way of searching is not to search at all. https://www.elastic.co/guide/en/elasticsearch/guide/current/_index_time_search_as_you_type.html
2.This particular cat may be skinned in myriad ways.
3.Updating Elasticsearch objects ("documents") is interesting for two reasons, a good one and a weird one:
    Good reason: documents are immutable. Updates involve marking the existing item as deleted and inserting a new document. 
        This is exactly how SQL Server 2014 IMOLTP works. It's one secret of extreme efficiency. It's an excellent practice to follow.
    Weird reason: you have to update to know the integer ID to update a document. It's highly efficient, which makes it, at worst, "weird"; not "bad". 
    It is allowed updates based on custom fields, you'd have a potential perf hit. Key lookups are the fastest.
4.If you have to deal with only a single language, count yourself lucky. Finding the right strategy for handling documents written in several languages can be challenging.
5.Full-text search is a battle between precision and recall.
6.The more frequently a term appears in a collection of documents, the less weight that term has
7.All languages, except Esperanto, are irregular. While more-formal words tend to follow a regular pattern, the most commonly used words often have irregular rules. 
8.Out-of-the-box stemming solutions are never perfect. 
9.Elasticsearch is a different kind of beast, especially if you come from the world of SQL.

Links:
1. Learning Elasticsearch with PowerShell https://netfxharmonics.com/2015/11/learningelasticps 
2. NEST - https://nest.azurewebsites.net/
3. Forum https://discuss.elastic.co/
4. ELASTICSEARCH CRUD .NET PROVIDER http://damienbod.com/2014/09/22/elasticsearch-crud-net-provider/
5. Network Settings - https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-network.html
6. Azure Templates - azure.microsoft.com/en-us/documentation/templates
7. http://solr-vs-elasticsearch.com/
8. cheatsheet http://elasticsearch-cheatsheet.jolicode.com/

The Elastic Stack — that's Elasticsearch, Logstash, Kibana, and Beats — are open source projects that help you take data from any source, any format and search, analyze
 and visualize it in real time. Products like Shield (security), Watcher (alerting), and Marvel (monitoring) extend what's possible with the Stack. And you can deploy it
 all as a service or on premise using Elastic Cloud.

Free and Open Source Products (Elastic Stack)
-------------
Lucene - low level search engine used by ElasticeSearch, Solr, and others. http://lucene.apache.org/
ElasticeSearch - Distributed, scalable, and highly available. Real-time search and analytics capabilities. Sophisticated RESTful API. https://www.elastic.co/products/elasticsearch
Kibana - Flexible analytics and visualization platform. Real-time summary and charting of streaming data. Intuitive interface for a variety of users. 
         Instant sharing and embedding of dashboards.
Logstash - Data pipeline (input->filter->output). Parsing framework. Centralize data processing of all types. Normalize varying schema and formats. Quickly extend to custom log formats. 
           Easily add plugins for custom data sources.
Beats - is the platform for building lightweight, open source data shippers for many types of operational data you want to enrich with Logstash, 
         search and analyze in Elasticsearch, and visualize in Kibana.
Marvel - Marvel enables you to easily monitor Elasticsearch through Kibana. Take the guesswork out of keeping Elasticsearch running at top speed. 
         Marvel keeps a pulse on the status of your deployment, helps you anticipate issues, troubleshoot problems quickly, and scale faster.

Comercial Products
-----------------
Shield - Authentication and encryption for Elasticsearch. Validated client, Separation of Duites, Authorization/Authentication, Least Priviledges Rule
          , Control of Application Accounts
Watcher - Alerting and notification product for Elasticsearch that lets you take action based on changes in your data. 
          It is designed around the principle that if you can query something in Elasticsearch, you can alert on it. 
          Simply define a query, condition, schedule, and the actions to take, and Watcher will do the rest. 
Elasticsearch Cloud - Elasticsearch from the Source Hosted and managed Elasticsearch in the Cloud. Free trial, free Kibana instance
        , and no credit card required. Nobody hosts Elasticsearch better.
Elasticsearch for Apache Hadoop (ES-Hadoop) - is the two-way connector that solves a top wishlist item for any Hadoop user out there: real-time search. 
         While the Hadoop ecosystem offers a multitude of analytics capabilities, it falls short with fast search. 
         ES-Hadoop bridges that gap, letting you leverage the best of both worlds: Hadoop's big data analytics and the real-time search of Elasticsearch.


Compare terminology.
Elastic   <=> DBMS
--------     --------
Cluster    =  Instance
Index      =  Database
Type       =  Table
Document   =  Row
Field      =  Column
Mapping    =  Schema
Cardinality=  Distinct values
Stemming   =  FORMOF, word breaker
ES Similarity != FTS Semantic Similarity
More Like This = FTS Semantic Similarity
Elasticsearch does not support ACID transactions. 

In terms of holly war/religion: Solr - like Oracle, ElasticSearch - like SQL Server. You need PHD to configure Oracle :)

Four common techniques are used to manage relational data in Elasticsearch:
-Application-side joins
-Data denormalization
-Nested objects
-Parent/child relationships
Data types: https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping-types.html
    -core: long, integer, short, byte, double, float, binary, boolean, date, string
    -complex: array, object, nested, geo_point, geo_shape, ip, completion, token_count, murmur3, attachment

Field could be indexed as an analyzed field for full-text search, and as a not_analyzed field for sorting or aggregations.

System Fields
-------------
_type
_id         unique ID / PK. Is autogenerated 20 charachter hash (if not provided)
            The _id field is not indexed as its value can be derived automatically from the _uid field.
_uid        _type + _id
_score      RANK
_source     By default, the JSON document that you index will be stored in the _source field and will be returned by all get and search requests.
_timestamp  is deprecated. Instead, use a normal date field and set its value explicitly.
_ttl        time to live number (in milliseconds), current version implementation is deprecated and will be replaced with a different implementation in a future version.
_mlt        More Like This

Glossary https://www.elastic.co/guide/en/elasticsearch/reference/2.2/glossary.html
---------    
Precision — returning as few irrelevant documents as possible.

Recall — returning as many relevant documents as possible.

Boosting -  is used in parameters to increase the relative weight of a clause 

Similarity  - (scoring / ranking model) defines how matching documents are scored. 
    Similarity is per field, meaning that via the mapping one can define a different similarity per field.
    
    Inflections => Synonyms:  "jumps,jumped,leap,leaps,leaped => jump", "cat,dog => pet", "little => small", ":)=>emoticon_happy", ":(=>emoticon_sad"
    The default similarity that is based on the TF/IDF mode
    BM25 - Another TF/IDF based similarity that has built-in tf normalization and is supposed to work better for short fields (like names).

Diacritics - symbols like ´, ^, and ¨. English uses diacritics only for imported words—like rôle, déjà, and däis. 
    Other languages require diacritics in order to be correct. 

Typoes and Mispelings - Fuzzy matching allows for query-time matching of misspelled words, while phonetic token filters at index time can be used for sounds-like matching.
    Fuzzy matching treats two words that are “fuzzily” similar as if they were the same word.

Stemming - reduce tokens to their root form: foxes → fox

Shard - is a single Lucene instance. It is a low-level “worker” unit which is managed automatically by elasticsearch

Routing - shard placement controlled by using a hash of the document’s id value. Data can be saved to multiple directories, and if each directory is mounted on a different hard drive, 

Relevance = Score - calculated weight or rank - _score

Proximity query - a phrase query with slop. 

Query - not cashed. Filter - cashable

MLT - more like this. Recommendation engine

Suggestions - Did you mean this/Autocomplete (Edge gramm - some*,Ngram - *ome*)

Pagination - from:size . results by page

Source field - By default, the JSON document that you index will be stored in the _source field and will be returned by all get and search requests. 
    This allows you access to the original object directly from search result

Aggregation - new replacement for facets, nested. Facet - not nested, is depricated and not used anymore

Fielddata - Aggregations work via a data structure known as fielddata. Fielddata is often the largest consumer of memory in an Elasticsearch cluster.
    Fielddata is not just used for aggregations. It is required for any operation that needs to look up the value contained in a specific document. Besides aggregations, this includes sorting, scripts that access field values, parent-child relationships

Recall — the number of relevant documents that a search returns.

TF/IDF - term frequency / inverse document frequency
    TF counts the number of times a term appears within the field we are querying in the current document. The more times it appears, the more relevant is this document.
    IDF takes into account how often a term appears as a percentage of all the documents in the index. The more frequently the term appears, the less weight it has.

Shingles - These word pairs (or bigrams) : ["sue ate", "ate the", "the alligator"]
    Shingles are not restricted to being pairs of words; you could index word triplets (trigrams) as well: ["sue ate the", "ate the alligator"]
    Trigrams give you a higher degree of precision, but greatly increase the number of unique terms in the index. 
    Bigrams are sufficient for most use cases.

The only practical difference between the prefix query and the prefix filter is that the filter can be cached.

Geohashes - are a way of encoding lat/lon points as strings. The original intention was to have a URL-friendly way of specifying geolocations,
    but geohashes have turned out to be a useful way of indexing geo-points and geo-shapes in databases.
Date Math:
    now+1h = the current time plus one hour, with ms resolution.
    now+1h+1m = The current time plus one hour plus one minute, with ms resolution.
    now+1h/d = The current time plus one hour, rounded down to the nearest day.
    2015-01-01||+1M/d  = 2015-01-01 plus one month, rounded down to the nearest day.

Plugins
---------
[string]$esPath = "C:\Search\elasticsearch-2.3.1"
cd "$esPath"

Usage instructions:
    cmd.exe /C "$esBinPath\bin\plugin.bat -h"
cls

List
    cmd.exe /C "$esBinPath\bin\elasticsearch-plugin.bat list"
Restore local Copy of configuration:
    Copy-Item ..\config\elasticsearch.yml -Destination .\bin -Force

Plugin can be installed using the plugin manager: 
    #https://www.elastic.co/guide/en/elasticsearch/plugins/2.0/delete-by-query-usage.html
    cmd.exe /C "$esPath\bin\plugin.bat install delete-by-query"

    cmd.exe /C ".\bin\plugin.bat install license"
    cmd.exe /C ".\bin\plugin.bat install marvel-agent"
    cmd.exe /C "C:\Search\kibana-4.5.0-windows\bin\kibana.bat plugin --install elasticsearch/marvel/latest"

    #https://www.elastic.co/guide/en/elasticsearch/plugins/master/mapper-attachments.html
    cmd.exe /C ".\bin\plugin.bat install mapper-attachments" 

    #The Azure Cloud plugin uses the Azure API for unicast discovery, and adds support for using Azure as a repository for Snapshot/Restore. https://www.elastic.co/guide/en/elasticsearch/reference/2.2/modules-snapshots.html
    cmd.exe /C ".\bin\plugin.bat install cloud-azure"

    cmd.exe /C "$esBinPath\plugin.bat install elasticsearch/elasticsearch-analysis-icu/$VERSION  
            #The current $VERSION can be found at https://github.com/elasticsearch/elasticsearch-analysis-icu.
            #https://www.elastic.co/guide/en/elasticsearch/guide/current/icu-plugin.html
        #Once installed, restart Elasticsearch, and you should see a line similar to the following in the startup logs:
        #[INFO][plugins] [Mysterio] loaded [marvel, analysis-icu], sites [marvel]
        #If you are running a cluster with multiple nodes, you will need to install the plug-in on every node in the cluster.

Plugin can be removed with the following command:
    cmd.exe /C ".\bin\plugin.bat remove delete-by-query"
    cmd.exe /C ".\bin\plugin.bat remove cloud-azure"


#Logstash
[string]$esPath = "C:\Search\elasticsearch-2.3.1"
cd "$esPath"

Usage instructions:
    cmd.exe /C "$esBinPath\bin\plugin.bat -h"
List
    cmd.exe /C "$esBinPath\bin\plugin.bat list"

    cmd.exe /C "$esBinPath\plugin.bat list"
    cmd.exe /C "$lsBinPath\plugin.bat list"
    cmd.exe /C "$lsBinPath\logstash agent -f C://Search//logstash-2.2.0//first-pipeline.conf"



ETL:
    cmd.exe /C "$lsBinPath\logstash -f logstash-simple.conf"
    cd $lsBinPath
    bin/logstash -f logstash-simple.conf
#>

[string]$uri = "http://localhost:9200"
[string]$indexName = "shared_v1"
[string]$esBinPath = "C:\Search\elasticsearch-5.0.0-alpha1"
[string]$lsBinPath = "C:\Search\logstash-2.3.0"
[string]$kbBinPath = "C:\Search\kibana-4.5.0-windows"

#indices API declaraions
$call = {
        param($verb, $params, $body)
        $headers = @{ 
            'Authorization' = 'Basic fVmBDcxgYWpndYXJj3RpY3NlkZzY3awcmxhcN2Rj'
        }

        <#Write-Host "`nCalling [$uri/$params]" -f Green
        if($body) {
            if($body) {
                Write-Host "BODY`n--------------------------------------------`n$body`n--------------------------------------------`n" -f Green
            }
        }#>
        $response = wget -Uri "$uri/$params" -method $verb -Headers $headers -ContentType 'application/json' -Body $body
        $response.Content #  | Select StatusCode, StatusDescription, Headers, Content | Write-Output #
    }

$get = {
        param($params)
        &$call "Get" $params
    }

$delete = {
        param($params)
        &$call "Delete" $params
    }
#&$delete /shared_v1/file,photo/_query?q=* #https://www.elastic.co/guide/en/elasticsearch/plugins/2.0/delete-by-query-usage.html
$put = {
        param($params,  $body)
        &$call "Put" $params $body
    }

$post = {
    param($params,  $body)
    &$call "Post" $params $body
}

$add = {
    param($index, $type, $json, $obj)
    if($obj) {
        $json = ConvertTo-Json -Depth 10 $obj
    }
    &$post "$index/$type" $json
}

$replace = {
    param($index, $type, $id, $json, $obj)
    if($obj) {
        $json = ConvertTo-Json -Depth 10 $obj
    }
    &$post "$index/$type/$id" $json
}

$update = {
    param($index, $type, $id, $json, $obj)
    if($obj) {
        $json = ConvertTo-Json -Depth 10 $obj
    }
    &$post "$index/$type/$id/_update" $json
}

$createIndex = {
        param($index, $json, $obj)
        if($obj) {
            $json = ConvertTo-Json -Depth 10 $obj
        }
        &$post $index $json
    }

$mapping = {
    param($index)
    &$get "$index/_mapping?pretty"
}
#&$mapping $indexName

$cat = {
    param($json)

    &$get "_cat/indices?v&pretty"
}
#get storage status summary before index
#ConvertFrom-Json (&$cat) | ft
(ConvertFrom-Json (&$cat)) | select index, docs.count, store.size |  ft
    #| where { $_.index -match '!files' }  `

Import-Module -Name .\ElasticSearch.Helper.psm1 -Force #-Verbose
$global:ElasticUri = $ElasticUri
#&$get
#&$call "Get" "/_cluster/state"
#&$cat
#test attachments
$fullPath = "C:\Search\Nova.Search\Fredrick Lafon THALES.pdf"
$fileContentBytes = [System.IO.File]::ReadAllBytes($fullPath);
$fileContentEncoded = [System.Convert]::ToBase64String($fileContentBytes)
&$createIndex "test" -obj @{
        mappings = @{
            file = @{
                properties = @{
                    my_attachment = @{
                        type = "attachment"
                    }
                }
            }
        }
    }
#simple JSON file attachment
&$add -index "test" -type 'file' -obj @{
    my_attachment = "$fileContentEncoded"
}
#Or it is possible to use more elaborated JSON if content type, resource name or language need to be set explicitly:
&$add -index "test" -type 'file' -obj @{
    my_attachment = @{
        _content_type = "application/pdf"
        _name = "resource/name/of/my.pdf"
        _language = "en"
        _content = "$fileContentEncoded"
    }
}

Invoke-Elasticsearch -Uri "$uri/$indexName/_cat/indices?v&pretty" -Method Default -Body

#&$delete $indexName 
#&$delete "shared"
#&$delete "content!staging"
#&$delete "shared_v1"
#&$delete 'shared/file' #type deleting is not available since v2.0 :(


#create index with mapped types
&$createIndex $indexName -obj @{
        mappings = @{
            file = @{
             dynamic = $true #will create new fields dynamically.
             date_detection = $false #avoid “malformed date” exception

             properties = @{
                #general properties
                Path = @{
                    type = "text"
        			#key = $true
                    #index = "not_analyzed"
                }
                Name = @{
                    type = "text"
                }
                Extension = @{
                    type = "text"
                }
                <#Content= @{ #multifield Content and Content.english
                    type="text"
                    fields = @{
                        english = @{ 
                            type = "text"
                            analyzer = "english"
                        }
                    }
                }#>
                Content = @{
                    type = "text"
                    analyzer = "english"
                }
                LastModified = @{
                    type = "date"
                    format = "YYYY-MM-DD"  
                }

                LastModifiedBy= @{
                    type = "text"
                }
                LastPrinted= @{
                    type = "text"
                }

                #custom properties
                Application= @{
                    type = "text"
                }
                AppVersion= @{
                    type = "text"
                    index = "not_analyzed"
                }
                Author= @{
                    type = "text"
                }
                Category= @{
                    type = "text"
                    index_analyzer = "autocomplete" #Use the autocomplete analyzer at index time to produce edge n-grams of every term.
                    search_analyzer = "standard" #Use the standard analyzer at search time to search only on the terms that the user has entered
                }
                Characters= @{
                    type = "text"
                }
                Comment= @{
                    type = "text"
                }
                Company= @{
                    type = "text"
                }
                Copyright= @{
                    type = "text"
                }
                Created= @{
                    type = "text"
                }
                Creator= @{
                    type = "text"
                }

                Description= @{
                    type = "text"
                }
                FileSource= @{
                    type = "text"
                }

                Keywords= @{
                    type = "text"
                }
                Manager= @{
                    type = "text"
                }
                Manufacturer= @{
                    type = "text"
                }
                Model= @{
                    type = "text"
                }
                Notes= @{
                    type = "text"
                }

                Revision= @{
                    type = "text"
                }
                SharedDoc= @{
                    type = "text"
                }
                Software= @{
                    type = "text"
                }
                Subject= @{
                    type = "text"
                }
                Template= @{
                    type = "text"
                }
                Title= @{
                    type = "text"
                }
                TitlesOfParts= @{
                    type = "text"
                }
                TotalTime= @{
                    type = "text"
                }

                #statistics
                #Pages and NumberOfPages may be merged ?
                Pages= @{#office docs
                    type = "text"
                    index = "not_analyzed"
                }
                NumberOfPages= @{ # from PDF
                    type = "integer"
                    index = "not_analyzed"
                }
                Words= @{
                    type = "text"
                }
                Orientation= @{
                    type = "text"
                }
                Paragraphs= @{
                    type = "text"
                }
                PresentationFormat= @{
                    type = "text"
                }
                FNumber= @{
                    type = "text"
                    index = "not_analyzed"
                }
                Lines= @{
                    type = "text"
                    index = "not_analyzed"
                }
                HLinks= @{
                    type = "text"
                }
                LinksUpToDate= @{
                    type = "text"
                }
                HyperlinkBase= @{
                    type = "text"
                }

                #Azure ML output based on Content
                Entities = @{
                    type = "nested"
                    properties = @{
                        Count = @{
                            type = "integer"
                            index = "not_analyzed"
                        }
                        Mention = @{
                            type = "text"
                        }
                        Type = @{
                            type = "text"
                        }
                    }
                }
            } #properties
         } #file

            photo = @{
             properties = @{
                #general properties
                Path = @{
                    type = "text"
        			#key = $True
                }
                Name = @{
                    type = "text"
                }
                Extension = @{
                    type = "text"
                }
                LastPrinted= @{
                    type = "text"
                }

                #Exif data
                ISO= @{
                    type = "text"
                }
                DateTaken= @{
                    type = "text"
                }
                DigitalZoomRatio= @{
                    type = "text"
                }
                Flash= @{
                    type = "text"
                }
                CaptureMode= @{
                    type = "text"
                }
                CharactersWithSpaces= @{
                    type = "text"
                }
                ColorSpace= @{
                    type = "text"
                }
                Latitute= @{
                    type = "text" #float geoip?
                }
                Longitude= @{
                    type = "text" #float geoip?
                }
                FocalLength= @{
                    type = "text"
                }
                FocalLength35mm= @{
                    type = "text"
                }
                Contrast= @{
                    type = "text"
                }
                LightSource= @{
                    type = "text"
                }
                MaxApperture= @{
                    type = "text"
                }
                MeteringMode= @{
                    type = "text"
                }
                MMClips= @{
                    type = "text"
                }
                Sharpness= @{
                    type = "text"
                }
                Slides= @{
                    type = "text"
                }
                HeadingPairs= @{
                    type = "text"
                }
                HiddenSlides= @{
                    type = "text"
                }
                Height= @{
                    type = "text"
                }
                ExposureBias= @{
                    type = "text"
                }
                ExposureMode= @{
                    type = "text"
                }
                ExposureProgram= @{
                    type = "text"
                }
                Exposuretime= @{
                    type = "text"
                }
                ScaleCrop= @{
                    type = "text"
                }
                Saturation= @{
                    type = "text"
                }
                WhiteBalance= @{
                    type = "text"
                }
                Width= @{
                    type = "text"
                }
            } #properties
        } #photo
      } #mappings
    } #obj

#create index alias
ConvertFrom-Json (&$cat) | ft
&$put "$indexName/_alias/shared"
#replace existing index alias ref
&$post "$indexName/_aliases" -body @{
    actions = @{
        <#remove = @{
            index ="shared_v0"
            alias = "shared"
        }#>
        add = @{
            index ="shared_v1"
            alias = "shared"
        }
    }
}
&$put "$indexName/_alias/shared"
&$get "$indexName/_alias"


&$add -index $indexName -type 'file' -json $json

<#https://www.elastic.co/guide/en/elasticsearch/guide/current/bulk.html
create - Create a document only if the document does not already exist. See Creating a New Document.
index - Create a new document or replace an existing document. See Indexing a Document and Updating a Whole Document.
update - Do a partial update on a document. See Partial Updates to Documents.
delete - Delete a document. See Deleting a Document.
#>

#JSON cannot include embedded newline characters. Newline characters in the script should either be escaped as \n or replaced with semicolons.
$body = '{"index": {"_type": "file", "_index": "shared_v1", "_id": "1"}'+ "`n" +
    '{"Extension":".pdf", "Name":"a16we_rev_54","Content":"DEPARTMENT OF TRANSPORTATION FEDERAL AVIATION ADMINISTRATION A16WE BOEING 737-100 Series 737-200 Series Boeing.","LastModified":"2015-09-23"}'+ "`n" +
'{"index": {"_type": "file", "_index": "shared_v1", "_id": "2"}'+"`n"+
    '{"Extension":".pdf","Length":1087273,"Name":"easa-tcds-a.120_(im)_volume_4_boeing_737--800-01-12122013","Content":"TCDSN No.: EASA.IM.A.120.4 Boeing 737 Page 1 of 236 Issue: 1 Date: 12 December 2013 TE.TC.00029-001-","LastModified":"2015-12-30","NumberOfPages":236,"Author":"keuppka","PDFParser":"iTextSharp","Entities":[{"Count":236,"Mention":"European Aviation Safety Agency. All","Type":"ORG"},{"Count":233,"Mention":"Boeing Company","Type":"ORG"},{"Count":2,"Mention":"Boeing","Type":"ORG"}]}'+"`n"
$result = &$post "_bulk" $body

$body = '{"create": {"_type": "file", "_id": "1"}'+ "`n" +
    '{"Extension":".pdf", "Name":"a16we_rev_54","Content":"DEPARTMENT OF TRANSPORTATION FEDERAL AVIATION ADMINISTRATION A16WE BOEING 737-100 Series 737-200 Series Boeing.","LastModified":"2015-09-23"}'+ "`n" +
'{"create": {"_type": "file", "_id": "2"}'+"`n"+
    '{"Extension":".pdf","Length":1087273,"Name":"easa-tcds-a.120_(im)_volume_4_boeing_737--800-01-12122013","Content":"TCDSN No.: EASA.IM.A.120.4 Boeing 737 Page 1 of 236 Issue: 1 Date: 12 December 2013 TE.TC.00029-001-","LastModified":"2015-12-30","NumberOfPages":236,"Author":"keuppka","PDFParser":"iTextSharp","Entities":[{"Count":236,"Mention":"European Aviation Safety Agency. All","Type":"ORG"},{"Count":233,"Mention":"Boeing Company","Type":"ORG"},{"Count":2,"Mention":"Boeing","Type":"ORG"}]}'+"`n"
$result = &$post "$indexName/_bulk" $body

$body = '{"create": {"_type": "file", "_id": "1"}'+ "`n" +
    '{"Extension":".pdf", "Name":"a16we_rev_54","Content":"DEPARTMENT OF TRANSPORTATION FEDERAL AVIATION ADMINISTRATION A16WE BOEING 737-100 Series 737-200 Series Boeing.","LastModified":"2015-09-23"}'+ "`n" +
'{"create": {"_type": "file", "_id": "2"}'+"`n"+
    '{"Extension":".pdf","Length":1087273,"Name":"easa-tcds-a.120_(im)_volume_4_boeing_737--800-01-12122013","Content":"TCDSN No.: EASA.IM.A.120.4 Boeing 737 Page 1 of 236 Issue: 1 Date: 12 December 2013 TE.TC.00029-001-","LastModified":"2015-12-30","NumberOfPages":236,"Author":"keuppka","PDFParser":"iTextSharp","Entities":[{"Count":236,"Mention":"European Aviation Safety Agency. All","Type":"ORG"},{"Count":233,"Mention":"Boeing Company","Type":"ORG"},{"Count":2,"Mention":"Boeing","Type":"ORG"}]}'+"`n"
$result = &$post "$indexName/_bulk" $body

$body = '{"index": {"_id": "1"}'+ "`n" +
    '{"Extension":".pdf", "Name":"a16we_rev_54","Content":"DEPARTMENT OF TRANSPORTATION FEDERAL AVIATION ADMINISTRATION A16WE BOEING 737-100 Series 737-200 Series Boeing.","LastModified":"2015-09-23"}'+ "`n" +
'{"index": {"_id": "2"}'+"`n"+
    '{"Extension":".pdf","Length":1087273,"Name":"easa-tcds-a.120_(im)_volume_4_boeing_737--800-01-12122013","Content":"TCDSN No.: EASA.IM.A.120.4 Boeing 737 Page 1 of 236 Issue: 1 Date: 12 December 2013 TE.TC.00029-001-","LastModified":"2015-12-30","NumberOfPages":236,"Author":"keuppka","PDFParser":"iTextSharp"}'+"`n"
$result = &$post "$indexName/file/_bulk" $body

&$get "$indexName/file/1"


$body = '{"delete": {"_type": "file", "_index": "shared_v1", "_id": "1"}'+ "`n" +
'{"delete": {"_type": "file", "_index": "shared_v1", "_id": "2"}'+"`n"
$result = &$post "_bulk" $body

$body = '{"delete": {"_type": "file", "_id": "AVN0XN7MiqPUF4ckPX7o"}'+ "`n" +
    '{"delete": {"_type": "file", "_id": "AVN0W5QBiqPUF4ckPX7n"}'+"`n"
$result = &$post "$indexName/_bulk" $body

#$result = &$call "Post" "_bulk" $body
$result = &$post "_bulk" $body
$result

ConvertFrom-Json (&$cat) | ft

GET /my_index/groups/_search
{
    "query": {
        "match_phrase": {
            "Entities.Mention": "Abraham Lincoln"
            "Entities.Type": "PER"
        }
    }
}
                #Azure ML output based on Content
                Entities = @{
                    type = "nested"
                    properties = @{
                        Count = @{
                            type = "integer"
                        }
                        Mention = @{
                            type = "text"
                        }
                        Type = @{
                            type = "text"
                        }
                    }
                }

                #Azure ML output based on Content
                Entities = @(
                    @{
                        Count = @{
                            type = "integer"
                        }
                        Mention = @{
                            type = "text"
                        }
                        Type = @{
                            type = "text"
                        }
                    }
                )





    #search API
    $search = {
        param($index, $json)

        &$get "$index/mydatatype/_search?pretty&source=$json"
    }


    &$get "$indexName/file,photo/_search?q=Content:sugar"

    &$search $indexName '{
        "query": {
            "match": {
                "Extension": "pdf"
            }
        }
    }'

    &$search $indexName '{
        "query" : {
            "filtered" : {
                "filter" : {
                    "range" : {
                        "age" : { "gt" : 30 } 
                    }
                },
                "query" : {
                    "match" : {
                        "last_name" : "smith" 
                    }
                }
            }
        }
    }'

    &$search $indexName '{
        "query": {
            "match_phrase": {
                "Path": "C:\\Search\\bac1898-34 iss a app.pdf"
            }
        }
    }'

    &$search $indexName '{
        "query": {
            "match": {
                "about": "METAL SURFACES"
            }
        }
    }'


    &$search $indexName '{
        "query": {
            "match_phrase": {
                "content": "METAL SURFACES IN ACCORDANCE"
            }
        }
    }'


    &$search $indexName (ConvertTo-Json @{
        query = @{
            match_phrase = @{
                content = "METAL"
            }
        }
        fields = @('Content', 'Name')
    })


    $search = {
        param($index, $json, $obj)
        if($obj) {
            $json = ConvertTo-Json -Depth 10 $obj
        }

       &$get "$index/mydatatype/_search?pretty&source=$json"
    }


    &$search $indexName -obj @{
        query = @{
            match_phrase = @{
                content = "struggling serves"
            }
        }
        fields = @('selector', 'title')
    }


    &$search $indexName '{
        "query": {
            "match_phrase": {
                "Content": "ISOMETRIC"
            }
        }
        "fields" = ["Content"]
    }'


    (ConvertFrom-Json(&$search $indexName 'entry' -obj @{
        query = @{
            match_phrase = @{
                content = "struggling serves"
            }
        }
        fields = @('selector', 'title')
    })).hits.hits.fields | ft


    $matchPhrase = {
        param($index, $type, $text, $fieldArray)
        (ConvertFrom-Json(&$search $index $type -obj @{
            query = @{
                match_phrase = @{
                    content = $text
                }
            }
            fields = $fieldArray
        })).hits.hits.fields | ft
    }

    $match = {
        param($index, $type, $text, $fieldArray)
        (ConvertFrom-Json(&$search $index $type -obj @{
            query = @{
                match = @{
                    content = $text
                }
            }
            fields = $fieldArray
        })).hits.hits.fields | ft
    }

    &$match $indexName 'file' 'even' @('selector', 'title')
    &$match $indexName 'file' 'even'

    $hits = $result.hits.hits
    $formatted = $hits | select `
            @{ Name='selector'; Expression={$_.fields.selector} },
            @{ Name='title'; Expression={$_.fields.title} }, 
            @{ Name='highlight'; Expression={$_.highlight.content} }
    $formatted

    #debugging
    $dump = {
        param($index, $type)
        &$get "$index/$type/_search?q=*:*&pretty"
    }
    #(ConvertFrom-Json(&$dump 'shared!files' 'entry')).hits.hits


    $serialize = {
        param($obj)
        if(!$pretty) {
            $pretty = $false
        }
        if($pretty) {
            ConvertTo-Json -Depth 10 $obj;
        }
        else {
            ConvertTo-Json -Compress -Depth 10 $obj
        }
    }

    $search = {
        param($index, $type, $json, $obj)
        if($obj) {
            $json = &$serialize $obj
        }
        &$get "$index/$type/_search?pretty&source=$json"
    }

    &$match $indexName 'file' 'struggling' @('selector', 'title')


    $setupTracking = {
        Add-Type -Path 'C:\Git\AB\IT\Apps\Nova.Search\packages\StackExchange.Redis.1.1.572-alpha\lib\net45\StackExchange.Redis.dll'
        $cs = '10.1.60.2'
        $config = [StackExchange.Redis.ConfigurationOptions]::Parse($cs)
        $connection = [StackExchange.Redis.ConnectionMultiplexer]::Connect($config)
        $connection.GetDatabase()
    }
    $redis = &$setupTracking


        #Get-Module -list Azure
        #get indexes
        [string]$url = "$SearchURL/indexes?api-version=$apiVersion&api-key=$SearchQueryKey"
        /indexes?api-version=2015-02-28
        [string]$url = "$SearchURL/indexes/hotels/docs?search=*&$orderby=lastRenovationDate desc&api-version=$apiVersion&api-key=$SearchQueryKey"
        (New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} #ignore test ssl certificate warning
    $Headers = @{
	    'Content-Type' = 'application/json; charset=utf-8'
	    'api-key' = $SearchPrimaryAdminKey # Provide Your API key
    }


    $IndexDefinition = @{
	    'name' = 'vacancies'
	    'fields' = @(
		    @{
			    'name' = 'VacancyId'
			    'type' = 'Edm.String'
			    'searchable' = $False
			    'filterable' = $False
			    'sortable' = $False
			    'facetable' = $False
			    'key' = $True
			    'retrievable' = $True
		    },
		    @{
			    'name' = 'Position'
			    'type' = 'Edm.String'
			    'searchable' = $True
			    'filterable' = $True
			    'sortable' = $True
			    'facetable' = $True
			    'key' = $False
			    'retrievable' = $True
                #"analyzer": "english"
                #'analyzer' = 'ru.lucene' # <--- Here is tricky part
                'analyzer' = 'ru.microsoft' # <--- Microsoft NLP can stemm russian words
		    }
	    )
        'suggesters' = @(
		    @{
			    'name' = 'sg'
			    'searchMode' = 'analyzingInfixMatching'
			    'sourceFields' = @('Position')
		    }
	    )

    }
    [string]$url = "$SearchURL/indexes?api-version=$apiVersion"
    Invoke-RestMethod -Method Post -Uri $url -Headers $Headers -Body ($IndexDefinition | ConvertTo-Json -Depth 10)




    if (!([System.Management.Automation.PSTypeName]'_netfxharmonics.hamlet.Generator').Type) {
        Add-Type -Language CSharp -TypeDefinition '
            namespace _Netfxharmonics.Hamlet {
                public static class Generator {
                    private static readonly string[] Words = "o my offence is rank it smells to heaven hath the primal eldest curse upont a brothers murder pray can i not though inclination be as sharp will stronger guilt defeats strong intent and like man double business bound stand in pause where shall first begin both neglect what if this cursed hand were thicker than itself with blood there rain enough sweet heavens wash white snow whereto serves mercy but confront visage of whats prayer two-fold force forestalled ere we come fall or pardond being down then ill look up fault past form serve turn forgive me foul that cannot since am still possessd those effects for which did crown mine own ambition queen may one retain corrupted currents world offences gilded shove by justice oft tis seen wicked prize buys out law so above no shuffling action lies his true nature ourselves compelld even teeth forehead our faults give evidence rests try repentance can yet when repent wretched state bosom black death limed soul struggling free art more engaged help angels make assay bow stubborn knees heart strings steel soft sinews newborn babe all well".Split('' '');
                    private static readonly int Length = Words.Length;
                    private static readonly System.Random Rand = new System.Random();

                    public static string Run(int count, bool subsequent = false) {
                        return Words[Rand.Next(1, Length)] + (count == 1 ? "" : " " + Run(count - 1, true));
                    }
                }
            }

        '
    }

    $ti = (Get-Culture).TextInfo
    (1..30).foreach({
        &$add -index $indexName -type 'entry' -obj @{
            selector = "{0}/{1}" -f ([_netfxharmonics.hamlet.Generator]::Run(1)), ([_netfxharmonics.hamlet.Generator]::Run(1))
            title = $ti.ToTitleCase([_netfxharmonics.hamlet.Generator]::Run(4))
            content = [_netfxharmonics.hamlet.Generator]::Run(400) + '.'
            created = [DateTime]::Now.ToString("yyyy-MM-dd")
            modified = [DateTime]::Now.ToUniversalTime().ToString("o")
        }
    })
    &$match $indexName 'entry' 'even'



    #delete index vacancies
    [string]$url = "$SearchURL/indexes/vacancies?api-version=$apiVersion"
    Invoke-RestMethod -Method Delete -Uri $url -Headers $Headers

    #http://mac-blog.org.ua/azure-search-cyrillic/
    #Insert some data
    $Documents = @{
	    'value' = @(
		    @{
			    'VacancyId' = '1'
			    'Position' = 'Менеджер по продажам в Киеве' # Translation: Sales manager in Kiev
		    },
		    @{
			    'VacancyId' = '2'
			    'Position' = '1-С Программист Киев' # Translation: 1-C programmer Kiev
		    },
		    @{
			    'VacancyId' = '3'
			    'Position' = '1-С Программист во Львове' # Translation: 1-C programmer Lviv
		    },
		    @{
			    'VacancyId' = '4'
			    'Position' = 'Acme ищет менеджера по продажам' # Translation: Acme search sales manager
		    }
	    )
    }
    [string]$url = "$SearchURL/indexes/vacancies/docs/index?api-version=$apiVersion"
    Invoke-RestMethod -Method Post -Uri $url -Headers $Headers -Body ([System.Text.Encoding]::UTf8.GetBytes(($Documents | ConvertTo-Json -Depth 10)))

    #get data
    [string]$url = "$SearchURL/indexes/vacancies/docs/index?api-version=$apiVersion&search=киеве"
    Invoke-RestMethod -Method Get -Uri $url -Headers $Headers | select -ExpandProperty value

        #Alternatively, you can use PUT and specify the index name on the URI. If the index does not exist, it will be created.



        $json = "api-key:$SearchPrimaryAdminKey"


        $json = @{"api-key:$SearchPrimaryAdminKey"} #convert request to POST body format, please use empty name ""= instead of "value"=

        #PUT https://[servicename].search.windows.net/indexes/[index name]?api-version=[api-version]
        $response = Invoke-RestMethod -Uri $url -Body $json -Method POST -UseDefaultCredentials -ContentType "application/json"
        $response | Format-Table





/_search
Search all types in all indices
/gb/_search
Search all types in the gb index
/gb,us/_search
Search all types in the gb and us indices
/g*,u*/_search
Search all types in any indices beginning with g or beginning with u
/gb/user/_search
Search type user in the gb index
/gb,us/user,tweet/_search
Search types user and tweet in the gb and us indices
/_all/user,tweet/_search

Pagination. You can use the from and size parameters for pagination:
GET /_search?size=5
GET /_search?size=5&from=5
GET /_search?size=5&from=10
GET /_search
{
  "from": 30,
  "size": 10
}

GET /shared/file,photo/_validate/query?explain 
{
   "query": {
      "tweet" : {
         "match" : "really powerful"
      }
   }
}


PUT /spanish_docs
{
    "settings": {
        "analysis": {
            "analyzer": {
                "es_std": {
                    "type":      "standard",
                    "stopwords": "_spanish_"
                }
            }
        }
    }
}

#To put it all together, the whole create-index request looks like this:
PUT /my_index
{
    "settings": {
        "analysis": {
            "char_filter": {
                "&_to_and": {
                    "type":       "mapping",
                    "mappings": [ "&=> and "]
            }},
            "filter": {
                "my_stopwords": {
                    "type":       "stop",
                    "stopwords": [ "the", "a" ]
            }},
            "analyzer": {
                "my_analyzer": {
                    "type":         "custom",
                    "char_filter":  [ "html_strip", "&_to_and" ],
                    "tokenizer":    "standard",
                    "filter":       [ "lowercase", "my_stopwords" ]
            }}
}}}

#After creating the index, use the analyze API to test the new analyzer:
#&$get "$IndexName/_analyze?analyzer=my_analyzer&text=The quick & brown fox"
#&$get "$IndexName/_analyze?analyzer=en_US&text=reorganizes"
#&$get "/spanish_docs/_analyze?analyzer=es_std&text=El veloz zorro marrón"
&$get "$IndexName/_analyze?analyzer=english&text=sky skies skiing skis" 
&$get "$IndexName/_analyze?analyzer=english&text=reorganizes"
&$get "$IndexName/_analyze?tokenizer=standard&filters=lowercase&text=The QUICK Brown FOX!"
#Like the lowercase filter, the asciifolding filter doesn’t require any configuration but can be included directly in a custom analyzer:
&$get "$IndexName/_analyze?tokenizer=standard&filters=asciifolding&text=My œsophagus caused a débâcle"

The multi_match query runs a match query on multiple fields and combines the results.
GET /_search
{
    "query": {
        "multi_match": { 
            "query":    "The quick brown fox",
            "fields": [ "blog_en.title", "blog_es.title" ]
        }
    }
}

Our new query uses the english analyzer for the field blog_en.title and the spanish analyzer for the field blog_es.title, and combines the results from both fields into an overall relevance score.


Set the my_index alias to point to my_index_v1.
PUT /my_index_v1/_alias/my_index

You can check which index the alias points to:
GET /*/_alias/my_index

Or which aliases point to the index:
GET /my_index_v1/_alias/*

Your application has switched from using the old index to the new index transparently, with zero downtime.
POST /_aliases
{
    "actions": [
        { "remove": { "index": "my_index_v1", "alias": "my_index" }},
        { "add":    { "index": "my_index_v2", "alias": "my_index" }}
    ]
}


#We could make this much more efficient by combining it with a cached filter: 
#we can exclude most of the month’s data by adding a filter that uses a fixed point in time, such as midnight last night:
"bool": {
    "must": [
        { "range" : { 
            "timestamp" : {
                "gt" : "now-1h/d" #This filter is cached because it uses now rounded to midnight. 
            }
        }},
        { "range" : {
            "timestamp" : {
                "gt" : "now-1h" #This filter is not cached because it uses now without rounding.
            }
        }}
    ]
}

#match phrase query
GET /my_index/my_type/_search
{
    "query": {
        "match_phrase": {
            "title": "quick brown fox"
        }
    }
}
#The match_phrase query can also be written as a match query with type phrase:
"match": {
    "title": {
        "query": "quick brown fox",
        "type":  "phrase"
    }
}
#The slop parameter tells the match_phrase query how far apart terms are allowed to be 
#while still considering the document a match. By how far apart we mean how many times 
#do you need to move a term in order to make the query and document match?
GET /my_index/my_type/_search
{
    "query": {
        "match_phrase": {
            "title": {
                "query": "quick fox",
                "slop":  1
            }
        }
    }
}


#The match query supports the minimum_should_match parameter, which allows you to specify the number of terms that must match for a document to be considered relevant. 
GET /my_index/my_type/_search
{
  "query": {
    "match": {
      "title": {
        "query":                "quick brown dog",
        "minimum_should_match": "75%"
      }
    }
  }
}

The boost parameter is used to increase the relative weight of a clause (with a boost greater than 1) or decrease the relative weight (with a boost between 0 and 1), but the increase or decrease is not linear. In other words, a boost of 2 does not result in double the _score.
GET /_search
{
    "query": {
        "bool": {
            "must": {
                "match": {  
                    "content": {
                        "query":    "full text search",
                        "operator": "and" #boost=1
                    }
                }
            },
            "should": [
                { "match": {
                    "content": {
                        "query": "Elasticsearch",
                        "boost": 3 
                    }
                }},
                { "match": {
                    "content": {
                        "query": "Lucene",
                        "boost": 2 
                    }
                }}
            ]
        }
    }
}


#The multi_match query provides a convenient shorthand way of running the same query against multiple fields.
{
    "multi_match": {
        "query":                "Quick brown fox",
        "type":                 "best_fields", 
        "fields":               [ "title", "body" ],
        "tie_breaker":          0.3,
        "minimum_should_match": "30%" 
    }
}


#Field names can be specified with wildcards: any field that matches the wildcard pattern will be included in the search. You could match on the book_title, chapter_title, and section_title fields, with the following:
{
    "multi_match": {
        "query":  "Quick brown fox",
        "fields": "*_title"
    }
}

#ndividual fields can be boosted by using the caret (^) syntax: just add ^boost after the field name, where boost is a floating-point number:
{
    "multi_match": {
        "query":  "Quick brown fox",
        "fields": [ "*_title", "chapter_title^2" ] #The chapter_title field has a boost of 2, while the book_title and section_title fields have a default boost of 1.
    }
}

#use the multi_match query instead, and set the type to most_fields to tell it to combine the scores of all matching fields:
{
  "query": {
    "multi_match": {
      "query":       "Poland Street W1V",
      "type":        "most_fields",
      "fields":      [ "street", "city", "country", "postcode" ]
    }
  }
}

#We can see this by passing our query through the validate-query API:
GET /_validate/query?explain
{
  "query": {
    "multi_match": {
      "query":   "Poland Street W1V",
      "type":    "most_fields",
      "fields":  [ "street", "city", "country", "postcode" ]
    }
  }
}
#which yields this explanation:
(street:poland   street:street   street:w1v)
(city:poland     city:street     city:w1v)
(country:poland  country:street  country:w1v)
(postcode:poland postcode:street postcode:w1v)



#The values in the first_name and last_name fields are also copied to the full_name field.
PUT /my_index
{
    "mappings": {
        "person": {
            "properties": {
                "first_name": {
                    "type":     "text",
                    "copy_to":  "full_name" 
                },
                "last_name": {
                    "type":     "text",
                    "copy_to":  "full_name" 
                },
                "full_name": {
                    "type":     "text"
                }
            }
        }
    }
}

#to find all distinct values strat from bucketing
GET /nova_v1/austender/_search
{
    "size" : 0,
    "aggs" : {
        "Agencies" : {
            "terms" : {
                "field" : "Agency"
            }
        }
    }
}

#Oh dear, that’s not at all what we want! Instead of counting states, the aggregation is counting individual words. 
#The underlying reason is simple: aggregations are built from the inverted index, and the inverted index is post-analysis.
#This is obviously not the behavior that we wanted, but luckily it is easily corrected.
#We need to define a multifield for state and set it to not_analyzed. This will prevent New York from being analyzed, which means it will stay a single token in the aggregation. 
DELETE /agg_analysis/
PUT /agg_analysis
{
  "mappings": {
    "data": {
      "properties": {
        "state" : {
          "type": "text",
          "fields": {
            "raw" : {
              "type": "text",
              "index": "not_analyzed"
            }
          }
        }
      }
    }
  }
}
#This time we explicitly map the state field and include a not_analyzed sub-field.
GET /agg_analysis/data/_search
{
  "size" : 0,
  "aggs" : {
    "states" : {
        "terms" : {
            "field" : "state.raw" 
        }
    }
  }
}
#So, before aggregating across fields, take a second to verify that the fields are not_analyzed. And if you want to aggregate analyzed fields, ensure that the analysis process is not creating an obscene number of tokens.
#????? Tip: At the end of the day, it doesn’t matter whether a field is analyzed or not_analyzed. The more unique values in a field—the higher the cardinality of the field—the more memory that is required. This is especially true for string fields, where every unique string must be held in memory—longer strings use more memory.


#To find all postcodes beginning with W1, we could use a simple prefix query:
GET /my_index/address/_search
{
    "query": {
        "prefix": {
            "postcode": "W1"
        }
    }
}
<#The prefix query or filter are useful for ad hoc prefix matching, but should be used with care. 
They can be used freely on fields with a small number of terms, but they scale poorly and can 
put your cluster under a lot of strain. Try to limit their impact on your cluster by using a 
long prefix; this reduces the number of terms that need to be visited.#>


<#The wildcard query is a low-level, term-based query similar in nature to the prefix query, 
but it allows you to specify a pattern instead of just a prefix. 
It uses the standard shell wildcards: ? matches any character, and * matches zero or more characters.#>
GET /my_index/address/_search
{
    "query": {
        "wildcard": {
            "postcode": "W?F*HW" 
        }
    }
}

#The regular expression says that the term must begin with a W, followed by any number from 0 to 9, followed by one or more other characters.
GET /my_index/address/_search
{
    "query": {
        "regexp": {
            "postcode": "W[0-9].+" 
        }
    }
}

<#The max_expansions parameter controls how many terms the prefix is allowed to match. 
It will find the first term starting with bl and keep collecting terms (in alphabetical order) 
until it either runs out of terms with prefix bl, or it has more terms than max_expansions.#>
{
    "match_phrase_prefix" : {
        "brand" : {
            "query": "johnnie walker bl",
            "max_expansions": 50
        }
    }
}

#Autocomplete!
#The first step is to configure a custom edge_ngram token filter, which we will call the autocomplete_filter:
{
    "filter": {
        "autocomplete_filter": {
            "type":     "edge_ngram",
            "min_gram": 1,
            "max_gram": 20
        }
    }
}

#Then we need to use this token filter in a custom analyzer, which we will call the autocomplete analyzer:
{
    "analyzer": {
        "autocomplete": {
            "type":      "custom",
            "tokenizer": "standard",
            "filter": [
                "lowercase",
                "autocomplete_filter" 
            ]
        }
    }
}

#The full request to create the index and instantiate the token filter and analyzer looks like this:
PUT /my_index
{
    "settings": {
        "number_of_shards": 1, #See Relevance Is Broken!.
        "analysis": {
            "filter": {
                "autocomplete_filter": { #First we define our custom token filter.
                    "type":     "edge_ngram",
                    "min_gram": 1,
                    "max_gram": 20
                }
            },
            "analyzer": {
                "autocomplete": {
                    "type":      "custom",
                    "tokenizer": "standard",
                    "filter": [
                        "lowercase",
                        "autocomplete_filter" #Then we use it in an analyzer.
                    ]
                }
            }
        }
    }
}
#test
GET /my_index/_analyze?analyzer=autocomplete
quick brown

#To use the analyzer, we need to apply it to a field, which we can do with the update-mapping API:
PUT /my_index/_mapping/my_type
{
    "my_type": {
        "properties": {
            "name": {
                "type":     "text",
                "analyzer": "autocomplete"
            }
        }
    }
}

#Now, we can index some test documents:
POST /my_index/my_type/_bulk
{ "index": { "_id": 1            }}
{ "name": "Brown foxes"    }
{ "index": { "_id": 2            }}
{ "name": "Yellow furballs" }

#If you test out a query for “brown fo” by using a simple match query
GET /my_index/my_type/_search
{
    "query": {
        "match": {
            "name": "brown fo"
        }
    }
}


#we can specify the index_analyzer and search_analyzer in the mapping for the name field itself. 
#Because we want to change only the search_analyzer, we can update the existing mapping without having to reindex our data:
PUT /my_index/my_type/_mapping
{
    "my_type": {
        "properties": {
            "name": {
                "type":            "text",
                "index_analyzer":  "autocomplete", #Use the autocomplete analyzer at index time to produce edge n-grams of every term.
                "search_analyzer": "standard" #Use the standard analyzer at search time to search only on the terms that the user has entered
            }
        }
    }
}


<#postcode field would need to be analyzed instead of not_analyzed, but you could use the keyword tokenizer to treat the postcodes as if they were not_analyzed.
Tip: The keyword tokenizer is the no-operation tokenizer, the tokenizer that does nothing. Whatever string it receives as input, it emits exactly the same string as a single token. It can therefore be used for values that we would normally treat as not_analyzed but that require some other analysis transformation such as lowercasing.
This example uses the keyword tokenizer to convert the postcode string into a token stream, so that we can use the edge n-gram token filter:#>
{
    "analysis": {
        "filter": {
            "postcode_filter": {
                "type":     "edge_ngram",
                "min_gram": 1,
                "max_gram": 8
            }
        },
        "analyzer": {
            "postcode_index": { #The postcode_index analyzer would use the postcode_filter to turn postcodes into edge n-grams.
                "tokenizer": "keyword",
                "filter":    [ "postcode_filter" ]
            },
            "postcode_search": { #The postcode_search analyzer would treat search terms as if they were not_indexed.
                "tokenizer": "keyword"
            }
        }
    }
}

#We could try to narrow it down to just the company by excluding words like pie, tart, crumble, and tree, using a must_not clause in a bool query:
GET /_search
{
  "query": {
    "bool": {
      "must": {
        "match": {
          "text": "apple"
        }
      },
      "must_not": {
        "match": {
          "text": "pie tart fruit crumble tree"
            }
      }
    }
  }
}

#But who is to say that we wouldn’t miss a very relevant document about Apple the company by excluding tree or crumble? Sometimes, must_not can be too strict.
#The boosting query solves this problem. It allows us to still include results that appear to be about the fruit or the pastries, but to downgrade them—to rank them lower than they would otherwise be:
GET /_search
{
  "query": {
    "boosting": {
      "positive": {
        "match": {
          "text": "apple"
        }
      },
      "negative": {
        "match": {
          "text": "pie tart fruit crumble tree"
        }
      },
      "negative_boost": 0.5
    }
  }
}



#Perhaps not all features are equally important—some have more value to the user than others. If the most important feature is the pool, we could boost that clause to make it count for more:
GET /_search
{
  "query": {
    "bool": {
      "should": [
        { "constant_score": {
          "query": { "match": { "description": "wifi" }}
        }},
        { "constant_score": {
          "query": { "match": { "description": "garden" }}
        }},
        { "constant_score": {
          "boost":   2  #A matching pool clause would add a score of 2, while the other clauses would add a score of only 1 each
          "query": { "match": { "description": "pool" }}
        }}
      ]
    }
  }
}

#we want to score vacation homes by the number of features that each home possesses. 
#we want to divide the results into subsets by using filters (one filter per feature), and apply a different function (weight) to each subset.
GET /_search
{
  "query": {
    "function_score": {
      "filter": { #This function_score query has a filter instead of a query.
        "term": { "city": "Barcelona" }
      },
      "functions": [ #The functions key holds a list of functions that should be applied.
        {
          "filter": { "term": { "features": "wifi" }}, #The function is applied only if the document matches the (optional) filter.
          "weight": 1
        },
        {
          "filter": { "term": { "features": "garden" }}, #The function is applied only if the document matches the (optional) filter.
          "weight": 1
        },
        {
          "filter": { "term": { "features": "pool" }}, #The function is applied only if the document matches the (optional) filter.
          "weight": 2 #The pool feature is more important than the others so it has a higher weight.
        }
      ],
      "score_mode": "sum", #The score_mode specifies how the values from each function should be combined.
    }
  }
}
<#
This is the role of the score_mode parameter, which accepts the following values:
multiply -Function results are multiplied together (default).
sum - Function results are added up.
avg - The average of all the function results.
max - The highest function result is used.
min - The lowest function result is used.
first - Uses only the result from the first function that either doesn’t have a filter or that has a filter matching the document.
#>

#To customize the behavior of the english analyzer, we need to create a custom analyzer that uses the english analyzer as its base but adds some configuration:
PUT /my_index
{
  "settings": {
    "analysis": {
      "analyzer": {
        "my_english": {
          "type": "english",
          "stem_exclusion": [ "organization", "organizations" ], #Prevents organization and organizations from being stemmed
          "stopwords": [ #Specifies a custom list of stopwords
            "a", "an", "and", "are", "as", "at", "be", "but", "by", "for",
            "if", "in", "into", "is", "it", "of", "on", "or", "such", "that",
            "the", "their", "then", "there", "these", "they", "this", "to",
            "was", "will", "with"
          ]
        }
      }
    }
  }
}

GET /my_index/_analyze?analyzer=my_english #Emits tokens world, health, organization, does, not, sell, organ
The World Health Organization does not sell organs.


The icu_tokenizer uses the same Unicode Text Segmentation algorithm as the standard tokenizer, but adds better support for some Asian languages by using a dictionary-based approach to identify words in Thai, Lao, Chinese, Japanese, and Korean, and using custom rules to break Myanmar and Khmer text into syllables.
For instance, compare the tokens produced by the standard and icu_tokenizers, respectively, when tokenizing “Hello. I am from Bangkok.” in Thai:
GET /_analyze?tokenizer=standard
สวัสดี ผมมาจากกรุงเทพฯ
The standard tokenizer produces two tokens, one for each sentence: สวัสดี, ผมมาจากกรุงเทพฯ. That is useful only if you want to search for the whole sentence “I am from Bangkok.”, but not if you want to search for just “Bangkok.”
GET /_analyze?tokenizer=icu_tokenizer
สวัสดี ผมมาจากกรุงเทพฯ

#Passing HTML through the standard tokenizer or the icu_tokenizer produces poor results. These tokenizers just don’t know what to do with the HTML tags. For example:
GET /_analyzer?tokenizer=standard
<p>Some d&eacute;j&agrave; vu <a href="http://somedomain.com>">website</a>
The standard tokenizer confuses HTML tags and entities, and emits the following tokens: p, Some, d, eacute, j, agrave, vu, a, href, http, somedomain.com, website, a. Clearly not what was intended!
Character filters can be added to an analyzer to preprocess the text before it is passed to the tokenizer. In this case, we can use the html_strip character filter to remove HTML tags and to decode HTML entities such as &eacute; into the corresponding Unicode characters.
Character filters can be tested out via the analyze API by specifying them in the query string:
GET /_analyzer?tokenizer=standard&char_filters=html_strip
<p>Some d&eacute;j&agrave; vu <a href="http://somedomain.com>">website</a>

To use them as part of the analyzer, they should be added to a custom analyzer definition:

PUT /my_index
{
    "settings": {
        "analysis": {
            "analyzer": {
                "my_html_analyzer": {
                    "tokenizer":     "standard",
                    "char_filter": [ "html_strip" ]
                }
            }
        }
    }
}
<#Once created, our new my_html_analyzer can be tested with the analyze API:

GET /my_index/_analyzer?analyzer=my_html_analyzer
<p>Some d&eacute;j&agrave; vu <a href="http://somedomain.com>">website</a>
Fortunately, it is possible to sort out this mess with the mapping character filter, which allows us to replace all instances of one character with another. In this case, we will replace all apostrophe variants with the simple U+0027 apostrophe:
#>
PUT /my_index
{
  "settings": {
    "analysis": {
      "char_filter": { 
        "quotes": {
          "type": "mapping",
          "mappings": [ 
            "\\u0091=>\\u0027",
            "\\u0092=>\\u0027",
            "\\u2018=>\\u0027",
            "\\u2019=>\\u0027",
            "\\u201B=>\\u0027"
          ]
        }
      },
      "analyzer": {
        "quotes_analyzer": {
          "tokenizer":     "standard",
          "char_filter": [ "quotes" ] 
        }
      }
    }
  }
}


<#We define a custom char_filter called quotes that maps all apostrophe variants to a simple apostrophe.
For clarity, we have used the JSON Unicode escape syntax for each character, but we could just have used the characters themselves: "‘=>'".
We use our custom quotes character filter to create a new analyzer called quotes_analyzer.

As always, we test the analyzer after creating it:

GET /my_index/_analyze?analyzer=quotes_analyzer
You're my ‘favorite’ M‛Coy
#>

#Synonyms can replace existing tokens or be added to the token stream by using the synonym token filter:

PUT /my_index
{
  "settings": {
    "analysis": {
      "filter": {
        "my_synonym_filter": {
          "type": "synonym", 
          "synonyms": [ 
            "british,english",
            "queen,monarch"
          ]
        }
      },
      "analyzer": {
        "my_synonyms": {
          "tokenizer": "standard",
          "filter": [
            "lowercase",
            "my_synonym_filter" 
          ]
        }
      }
    }
  }
}

<#First, we define a token filter of type synonym.
We discuss synonym formats in Formatting Synonyms.
Then we create a custom analyzer that uses the my_synonym_filter.#>

#If a time_zone of -01:00 is specified, then midnight starts at one hour before midnight UTC:
GET my_index/_search?size=0
{
  "aggs": {
    "by_day": {
      "date_histogram": {
        "field":     "date",
        "interval":  "day",
        "time_zone": "-01:00"
      }
    }
  }
}

#Setting the offset parameter to +6h would change each bucket to run from 6am to 6am:
GET my_index/_search?size=0
{
  "aggs": {
    "by_day": {
      "date_histogram": {
        "field":     "date",
        "interval":  "day",
        "offset":    "+6h"
      }
    }
  }
}

          "filter": { 
            "range": {
               "sold": {
                  "from": "now-5Y"
               }
            }


PUT /music/_warmer/warmer_1 #Warmers are associated with an index (music) and are registered using the _warmer endpoint and a unique ID (warmer_1).
{
  "query" : {
    "filtered" : {
      "filter" : {
        "bool": {
          "should": [ #The three most popular music genres have their filter caches prebuilt.
            { "term": { "tag": "rock"        }},
            { "term": { "tag": "hiphop"      }},
            { "term": { "tag": "electronics" }}
          ]
        }
      }
    }
  },
  "aggs" : {
    "price" : {
      "histogram" : {
        "field" : "price", #The fielddata and global ordinals for the price field will be preloaded.
        "interval" : 10
      }
    }
  }
}


GET /shared_v1/photo/_search
{
  "query": {
    "filtered": {
      "filter": {
        "geo_bounding_box": {
          "GPS": { 
            "top_left": {
              "lat":  -33,
              "lon": 151
            },
            "bottom_right": {
              "lat":  -33,
              "lon": 152
            }
          }
        }
      }
    }
  }
}

GET /shared_v1/photo/_search
{
  "query": {
    "filtered": {
      "filter": {
         "geo_distance": {
          "distance": "100km", 
          "distance_type": "plane", #Use the faster but less accurate plane calculation.
          "GPS": { 
            "lat": -33,
            "lon": 151
          }
        }
      }
    }
  },
    "sort": [
        {
            "_geo_distance": {
            "GPS": {                 #Calculate the distance between the specified lat/lon point and the geo-point in the location field of each document.
                "lat": -33.8,
                "lon": 151.2
            },
            "order":         "asc",
            "unit":          "km",   #Return the distance in km in the sort keys for each result.
            "distance_type": "plane" #Use the faster but less accurate plane calculation.
            }
        }
     ]
}

GET /shared_v1/photo/_search
{
  "query": {
    "filtered": {
      "filter": {
        "geo_distance_range": {
          "gte":    "50km", 
          "lt":     "100km", 
          "GPS": {
            "lat":  -33,
            "lon": 151
          }
        }
      }
    }
  }
}


This hierarchy can be generated automatically from the path field using the path_hierarchy tokenizer:

PUT /fs
{
  "settings": {
    "analysis": {
      "analyzer": {
        "paths": { 
          "tokenizer": "path_hierarchy" #The custom paths analyzer uses the path_hierarchy tokenizer with its default settings.
        }
      }
    }
  }
}