cls
#[string]$Root = "C:\Search\solr-5.4.0\"
[string]$Root = "C:\Java\solr-5.3.1"
&$Root\bin\solr -e dih
&"$($Root)\bin\solr" start #-p 8983
&$Root\bin\solr -e techproducts #Start Solr with a Specific Example Configuration
&$Root\bin\solr status
&$Root\bin\solr stop -p 8983


#bin/solr create -c library_core
#get-psdrive -psprovider filesystem
#java -Dc=library -Drecursive=true -jar "C:\Search\solr-5.4.0\example\exampledocs\post.jar" "L:\"
#java -Dc=library -Drecursive=yes -Ddata=files -jar "C:\Search\solr-5.4.0\example\exampledocs\post.jar" "L:\*.*" #"\\dfs\library\" 
#java -Dc=library -Drecursive -Dauto=true -jar C:\Search\solr-5.4.0\example\exampledocs\post.jar L:\_Instructions\ #-filetypes ppt,html
java -Dc=library_core -Ddata=files -Drecursive -Dauto=true -jar C:\Search\solr-5.4.0\example\exampledocs\post.jar \\dfs\library\_Instructions\
java -Dc=library_core -Ddata=files -Drecursive -Dauto=true -jar C:\Java\solr-5.3.1\example\exampledocs\post.jar C:\Temp

java -jar C:\Search\solr-5.4.0\server\start.jar --help
java -jar C:\Search\solr-5.4.0\server\start.jar --stop
