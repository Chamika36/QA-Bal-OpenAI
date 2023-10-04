import ballerina/io;
import ballerinax/openai.embeddings;
import ballerinax/googleapis.sheets as sheets;
import ballerinax/pinecone.vector as pinecone;
import ballerina/lang.runtime;


configurable string sheetsAccessToken = ?;
configurable string sheetId = ?;
configurable string sheetName = ?;
configurable string openAIToken = ?;
configurable string pineconeKey = ?;
configurable string pineconeServiceUrl = ?;

const NAMESPACE = "ChoreoDocs";
const EMBEDDING_MODEL = "text-embedding-ada-002";

final embeddings:Client embeddingsClient = check new({
    auth: {token: openAIToken}
});

final sheets:Client sheetsClient = check new({
    auth: {token: sheetsAccessToken}
});

final pinecone:Client pineconeClient = check new(
    {apiKey: pineconeKey},
    serviceUrl = pineconeServiceUrl
);

function getEmbedding(string text) returns float[]|error{
    embeddings:CreateEmbeddingResponse embeddingRes = check embeddingsClient->/embeddings.post({
        model: EMBEDDING_MODEL, 
        input: text
        });
    return embeddingRes.data[0].embedding;
}

public function main() returns error? {
    pinecone:Vector[] vectors = [];
    sheets:Range|error rangeResult = sheetsClient->getRange(sheetId, sheetName, "A2:B");
    sheets:Range range = check rangeResult;

    foreach any[] row in range.values {
        string title = row[0].toString();
        string content = row[1].toString();
        float[]|error embedding = getEmbedding(content);
        vectors.push({id: title, values: check embedding, metadata: {"content": content}});

        runtime:sleep(60.0/3);
    }

    _ = check pineconeClient->/vectors/upsert.post({
        namespace: NAMESPACE,
        vectors
    });

    io:println("Hello, World!");
}
