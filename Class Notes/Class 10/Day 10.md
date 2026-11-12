# Day 10: MongoDB and Document Databases

This class introduces **MongoDB**, a popular NoSQL, document-oriented database designed for scalability, flexibility, and high performance. Unlike traditional relational databases that use tables and rows, MongoDB stores data in flexible, JSON-like documents called BSON (Binary JSON). We discuss:

- What MongoDB is and why it exists
- BSON (Binary JSON) as MongoDB's storage format
- Documents and collections as the core data model
- CRUD operations with MongoDB's query language
- NoSQL vs SQL comparison
- CAP Theorem and distributed systems trade-offs
- Read and write concerns for consistency tuning
- Retryable reads and writes for fault tolerance
- Collection methods and index management
- The aggregation framework for data processing
- MongoDB architecture: replica sets and sharding

---

## 1. What Is MongoDB?

**MongoDB** is a NoSQL, document-oriented database designed for scalability, flexibility, and high performance. It stores data in JSON-like BSON (Binary JSON) format, allowing for the representation of complex data structures and enabling developers to work with unstructured or semi-structured data easily. MongoDB provides a rich query language, supports horizontal scaling through sharding, and offers features like indexing, aggregation, and real-time analytics.

### Why MongoDB Exists

Before document databases existed, most applications relied on relational databases that required rigid, predefined schemas. This approach worked well for structured data but created friction when applications needed to evolve quickly or handle semi-structured and unstructured data.

**Problems MongoDB solves:**

- **Rigid schema**: Relational databases require schema changes (`ALTER TABLE`) when data structures change, which can be slow and risky on large production tables.
- **Object-relational impedance mismatch**: Applications work with objects and nested data, but relational databases flatten everything into tables and rows.
- **Scalability limits**: Traditional RDBMSs scale vertically (bigger hardware) more easily than horizontally (more machines).
- **Unstructured data**: Many modern data sources (web logs, sensor data, user profiles, content) do not fit neatly into fixed-column tables.

### MongoDB's Approach

MongoDB replaces tables and rows with **collections and documents**:

- A **collection** is analogous to a table — it holds a group of related documents.
- A **document** is analogous to a row — it is a single record stored as BSON.
- Instead of fixed columns, each document contains **fields** (key-value pairs), and different documents in the same collection can have different structures.

```text
Relational (SQL)      MongoDB (NoSQL)
Database              Database
Table                 Collection
Row                   Document
Column                Field
JOIN                  $lookup / embedded documents
Primary Key           _id field
```

> **Key takeaway:** MongoDB trades the rigid structure of relational tables for flexible documents, enabling faster iteration, horizontal scaling, and natural mapping to application objects.

---

## 2. BSON: Binary JSON

**BSON** (Binary JSON) is MongoDB's binary-encoded serialization format. It extends JSON with additional data types and optimizations while maintaining JSON's flexibility and document structure.

### BSON vs JSON

| Feature     | JSON                            | BSON                            |
|-------------|---------------------------------|---------------------------------|
| Format      | Human-readable text             | Binary-encoded                  |
| Parsing     | Slower (text parsing)           | Faster (binary parsing)         |
| Storage     | Larger (text overhead)          | More compact                    |
| Data types  | String, number, boolean, null, array, object | JSON types + date, binary, ObjectId, int32, int64, Decimal128 |
| Date support| No (strings only)               | Yes (native Date type)          |

### BSON Data Types

MongoDB's BSON supports all standard JSON types plus several MongoDB-specific types:

| Type          | Description                  | Example                              |
|---------------|------------------------------|--------------------------------------|
| String        | UTF-8 text                   | `"hello"`                            |
| Integer       | 32-bit or 64-bit             | `42` (int32), `NumberLong("...")`    |
| Double        | Floating-point               | `3.14`                               |
| Decimal128    | High-precision decimal       | `NumberDecimal("10.99")`             |
| Boolean       | True/false                   | `true`                               |
| Array         | Ordered list                 | `[1, 2, 3]`                          |
| Object/Document| Embedded document           | `{ name: "Alice", age: 30 }`         |
| Null          | Null value                   | `null`                               |
| ObjectId      | 12-byte unique identifier    | `ObjectId("507f1f77bcf86cd799439011")` |
| Date          | UTC datetime                 | `ISODate("2024-01-15T10:30:00Z")`    |
| Binary data   | Raw bytes                    | `BinData(0, "...")`                  |
| Regular expression| Pattern matching         | `/pattern/`                          |

### Example BSON Document

```json
{
  "_id": ObjectId("507f1f77bcf86cd799439011"),
  "name": "Alice Smith",
  "age": 30,
  "email": "alice@example.com",
  "address": {
    "street": "123 Main St",
    "city": "Chicago",
    "zip": "60601"
  },
  "tags": ["developer", "database", "mongodb"],
  "created_at": ISODate("2024-01-15T10:30:00Z"),
  "is_active": true,
  "score": NumberDecimal("98.5")
}
```

**Document rules:**
- Field names are strings.
- Field names cannot contain the null character (`\0`).
- Field names cannot start with `$` (reserved for MongoDB operators).
- Field names cannot contain `.` (used for nested field access).
- Documents have a maximum size of 16 MB.

> **Key takeaway:** BSON combines JSON's flexible document structure with binary efficiency and richer native data types, making it ideal for fast storage, retrieval, and parsing in MongoDB.

---

## 3. Documents and Collections

### Documents

A document is the basic unit of data in MongoDB. It is stored as BSON and consists of field-value pairs. Every document has a special `_id` field that serves as its primary key. If a document is inserted without an `_id`, MongoDB generates one automatically.

**Document structure:**

```json
{
  "_id": ObjectId("..."),
  "field1": value1,
  "field2": value2,
  "nested": {
    "subfield": value3
  },
  "array": [value4, value5]
}
```

### Collections

A **collection** is a grouping of MongoDB documents, equivalent to a table in a relational database. Collections exist within a database.

**Key characteristics:**
- Collections are **schema-less**: documents in the same collection can have different fields.
- Collections are created implicitly when you first insert data into them.
- You can optionally create collections explicitly with validation rules.
- Collections support indexes for fast queries.

```text
Database: lab_6020
  ├── Collection: users
  │   ├── { _id: 1, name: "Alice", age: 30, email: "alice@example.com" }
  │   ├── { _id: 2, name: "Bob", age: 25, phone: "555-1234" }
  │   └── { _id: 3, name: "Carol", age: 35, email: "carol@example.com", tags: ["admin"] }
  └── Collection: orders
      ├── { _id: 101, user_id: 1, item: "Widget", price: 19.99, status: "shipped" }
      └── { _id: 102, user_id: 2, item: "Gadget", price: 29.99, status: "pending" }
```

> **Key takeaway:** Documents are flexible, self-contained records stored as BSON; collections group documents together without requiring a uniform schema across all documents.

---

## 4. CRUD Operations in MongoDB

MongoDB provides a rich set of methods for creating, reading, updating, and deleting documents.

### Create (Insert)

```javascript
// Insert a single document
db.users.insertOne({
  name: "Alice Smith",
  age: 30,
  email: "alice@example.com",
  tags: ["developer", "mongodb"]
});

// Insert multiple documents
db.users.insertMany([
  { name: "Bob Jones", age: 25, email: "bob@example.com" },
  { name: "Carol White", age: 35, email: "carol@example.com", tags: ["admin"] }
]);
```

### Read (Find)

```javascript
// Find all documents in a collection
db.users.find();

// Find documents matching a filter
db.users.find({ age: { $gt: 25 } });

// Find with projection (select specific fields)
db.users.find({ age: { $gt: 25 } }, { name: 1, email: 1, _id: 0 });

// Find one document
db.users.findOne({ email: "alice@example.com" });

// Find with sort and limit
db.users.find().sort({ age: -1 }).limit(5);
```

### Update

```javascript
// Update one document
db.users.updateOne(
  { email: "alice@example.com" },
  { $set: { age: 31, city: "Chicago" } }
);

// Update multiple documents
db.users.updateMany(
  { tags: "developer" },
  { $set: { department: "Engineering" } }
);

// Replace a document entirely
db.users.replaceOne(
  { email: "bob@example.com" },
  { name: "Bob Smith", age: 26, email: "bob.smith@example.com" }
);

// Increment a field
db.users.updateOne(
  { name: "Alice Smith" },
  { $inc: { age: 1 } }
);

// Push to an array
db.users.updateOne(
  { name: "Alice Smith" },
  { $push: { tags: "nosql" } }
);
```

### Delete

```javascript
// Delete one document
db.users.deleteOne({ email: "bob@example.com" });

// Delete multiple documents
db.users.deleteMany({ age: { $lt: 30 } });

// Delete all documents (keeps collection)
db.users.deleteMany({});

// Drop the entire collection
db.users.drop();
```

### Query Operators

MongoDB supports a rich set of query operators for filtering documents:

| Operator | Meaning              | Example                                               |
|----------|----------------------|-------------------------------------------------------|
| `$eq`    | Equal                | `{ age: { $eq: 30 } }`                                |
| `$gt`    | Greater than         | `{ age: { $gt: 25 } }`                                |
| `$gte`   | Greater than or equal| `{ age: { $gte: 30 } }`                               |
| `$lt`    | Less than            | `{ age: { $lt: 40 } }`                                |
| `$lte`   | Less than or equal   | `{ age: { $lte: 35 } }`                               |
| `$ne`    | Not equal            | `{ age: { $ne: 30 } }`                                |
| `$in`    | In array             | `{ status: { $in: ["shipped", "pending"] } }`         |
| `$nin`   | Not in array         | `{ status: { $nin: ["cancelled"] } }`                 |
| `$and`   | Logical AND          | `{ $and: [{ age: { $gt: 25 } }, { city: "Chicago" }] }` |
| `$or`    | Logical OR           | `{ $or: [{ age: { $lt: 30 } }, { city: "New York" }] }` |
| `$not`   | Logical NOT          | `{ age: { $not: { $gt: 30 } } }`                      |
| `$exists`| Field exists         | `{ middle_name: { $exists: false } }`                 |
| `$regex` | Pattern match        | `{ name: { $regex: /^A/ } }`                          |

> **Key takeaway:** MongoDB's CRUD API uses JSON-like queries with special operators (`$gt`, `$in`, `$set`, `$push`, etc.) that provide expressive filtering and modification capabilities without SQL.

---

## 5. NoSQL vs SQL

MongoDB represents the NoSQL paradigm, which differs fundamentally from traditional SQL databases.

### SQL Databases (Relational)

| Characteristic | Description                                 |
|----------------|---------------------------------------------|
| Schema         | Rigid, predefined tables with fixed columns |
| Data model     | Tables, rows, columns                       |
| Query language | SQL                                         |
| Scaling        | Primarily vertical (bigger server)          |
| ACID           | Full ACID compliance                        |
| Joins          | Native JOIN operations across tables        |
| Best for       | Structured data, complex transactions, financial systems |

### NoSQL Databases (Document / MongoDB)

| Characteristic | Description                                                       |
|----------------|-------------------------------------------------------------------|
| Schema         | Dynamic, flexible — documents can vary                            |
| Data model     | Collections of BSON documents                                     |
| Query language | MongoDB query language (JSON-like)                                |
| Scaling        | Horizontal (sharding across machines)                             |
| ACID           | Document-level ACID; multi-document transactions supported        |
| Joins          | `$lookup` aggregation stage or embedded documents                 |
| Best for       | Unstructured/semi-structured data, rapid iteration, content management |

### Direct Comparison

| Scenario                        | SQL (Relational)              | NoSQL (MongoDB)             |
|---------------------------------|-------------------------------|-----------------------------|
| Fixed, well-known schema        | Excellent fit                 | Overkill                    |
| Evolving, unpredictable schema  | Painful (`ALTER TABLE`)       | Natural fit                 |
| Complex multi-row transactions  | Strong ACID                   | Document-level ACID         |
| Horizontal scaling              | Difficult                     | Native sharding             |
| Nested/hierarchical data        | Requires multiple tables + JOINs | Single document         |
| Rapid prototyping               | Schema migration overhead     | Insert and go               |

### When to Choose Each

**Choose SQL when:**
- Data is highly structured and relationships are complex.
- You need strong ACID guarantees across many tables.
- You require complex ad-hoc queries with many JOINs.
- Data integrity is paramount (financial, healthcare systems).

**Choose MongoDB when:**
- Data is semi-structured or unstructured.
- The schema evolves frequently.
- You need horizontal scalability for large volumes.
- You work with content management, catalogs, user profiles, or IoT data.
- Rapid development and iteration are priorities.

> **Key takeaway:** SQL and NoSQL are not competitors but complementary tools. SQL excels at structured data with complex relationships; MongoDB excels at flexible, scalable document storage for modern applications.

---

## 6. CAP Theory

**CAP Theorem** (Brewer's Theorem) states that a distributed system can provide at most two of the following three guarantees simultaneously:

| Guarantee | Meaning                                                               |
|-----------|-----------------------------------------------------------------------|
| **C**onsistency | Every read receives the most recent write or an error.            |
| **A**vailability| Every request receives a response (non-error), without guarantee it contains the most recent write. |
| **P**artition tolerance | The system continues to operate despite network partitions.      |

### The Trade-Off

In a distributed system, network partitions are inevitable. Therefore, you must choose between consistency and availability when a partition occurs:

```text
                    CAP Theorem
                         |
              Partition happens? (P = yes in distributed systems)
                     /                 \
                Yes                     No
                 |                       |
         Choose C or A               Can have both C and A
          /          \
      CP              AP
```

### CP System (Consistency + Partition Tolerance)

- Sacrifices availability during a partition.
- If a node cannot communicate with the majority, it refuses writes.
- Example: MongoDB with `w: "majority"` write concern ensures consistency but may reject writes during a partition.

### AP System (Availability + Partition Tolerance)

- Sacrifices consistency during a partition.
- All nodes remain available for reads and writes, but data may be inconsistent.
- Example: Systems that allow writes to any node and reconcile later (eventual consistency).

### CA System (Consistency + Availability)

- Only possible in single-node systems (no partitions).
- Not applicable to distributed databases.

### MongoDB and CAP

MongoDB is a **CP system by default**. It prioritizes consistency and partition tolerance:

- Write operations require acknowledgment from a majority of replica set members (configurable).
- During a network partition, the minority side becomes unavailable for writes.
- Reads can be configured for eventual consistency (read preference: secondary) or strong consistency (read preference: primary).

> **Key takeaway:** CAP forces a trade-off between consistency and availability during network partitions. MongoDB defaults to CP, favoring consistency over availability when partitions occur.

---

## 7. Read and Write Concerns

MongoDB provides **read concern** and **write concern** to control consistency and acknowledgment levels for operations.

### Write Concern

Write concern specifies the level of acknowledgment required from MongoDB for write operations (insert, update, delete).

| Write Concern | Meaning                                        | Durability | Performance |
|---------------|------------------------------------------------|------------|-------------|
| `w: 0`        | Unacknowledged — no confirmation required      | Lowest     | Fastest     |
| `w: 1`        | Acknowledged by primary only                   | Moderate   | Fast        |
| `w: "majority"`| Acknowledged by majority of replica set      | High       | Slower      |
| `w: "all"`    | Acknowledged by all voting members             | Highest    | Slowest     |
| `w: N`        | Acknowledged by N members                      | Configurable| Configurable|

**Example:**

```javascript
// Write acknowledged by primary only
db.orders.insertOne(
  { item: "Widget", price: 19.99 },
  { writeConcern: { w: 1 } }
);

// Write acknowledged by majority (stronger durability)
db.orders.insertOne(
  { item: "Widget", price: 19.99 },
  { writeConcern: { w: "majority", j: true } }
);
```

The `j: true` option requires the write to be journaled (written to the on-disk journal) before acknowledgment, providing additional durability.

### Read Concern

Read concern determines the consistency and isolation guarantees for read operations.

| Read Concern  | Meaning                                                                 | Guarantees                                          |
|---------------|-------------------------------------------------------------------------|-----------------------------------------------------|
| `local`       | Returns data from the local node, no guarantee it has been replicated   | Most recent on this node, may be rolled back        |
| `available`   | Returns data from the most recent write on any node                     | Available but may be stale                          |
| `majority`    | Returns data acknowledged by a majority of replica set members          | No rollback, consistent with majority               |
| `linearizable`| Returns data that reflects all successful majority-acknowledged writes  | Strongest consistency, reads from primary           |
| `snapshot`    | Returns data from a specific point in time (multi-document transactions)| Consistent snapshot                                 |

**Example:**

```javascript
// Read with majority concern (consistent, may wait for replication)
db.orders.find({ status: "shipped" }).readConcern("majority");

// Read with linearizable concern (strongest consistency)
db.orders.find({ _id: orderId }).readConcern("linearizable");
```

### Combining Read and Write Concerns

You can tune read and write concerns independently to balance performance and consistency:

```javascript
// Fast writes, eventually consistent reads (AP-leaning)
db.orders.insertOne({ item: "Widget" }, { writeConcern: { w: 1 } });
db.orders.find().readConcern("local");

// Durable writes, strongly consistent reads (CP-leaning)
db.orders.insertOne({ item: "Widget" }, { writeConcern: { w: "majority", j: true } });
db.orders.find().readConcern("majority");
```

> **Key takeaway:** Write concern controls how many nodes must acknowledge a write; read concern controls how up-to-date the data a read returns must be. Together, they let you tune the consistency-performance trade-off for each operation.

---

## 8. Retryable Reads and Writes

**Retryable reads and writes** are client-side features in MongoDB drivers that automatically retry certain operations when they fail due to transient errors.

### Why Retryable Operations Matter

In distributed environments (cloud deployments, replica sets), transient failures are common:
- Network blips between client and server
- Replica set elections (primary steps down, new primary elected)
- Temporary server unavailability
- Failover events

Without retryable logic, applications must catch and handle these errors manually. With retryable reads/writes, the driver handles them transparently.

### Retryable Writes

MongoDB drivers can automatically retry certain write operations exactly once when they fail due to recoverable errors:

- `insertOne`
- `updateOne` / `updateMany`
- `replaceOne`
- `deleteOne` / `deleteMany`
- `findAndModify`

Retryable writes are enabled by default in MongoDB drivers connected to a replica set or sharded cluster.

```javascript
// Retryable write (enabled by default)
db.orders.insertOne({ item: "Widget", price: 19.99 });

// The driver automatically retries once if the write fails due to:
// - Network error
// - Replica set election
// - Temporary server unavailability
```

**Retryable write requirements:**
- The operation must be idempotent (safe to apply twice).
- The connection must use a replica set or sharded cluster (not standalone).
- The write concern must be `w: 1` or `w: "majority"`.

### Retryable Reads

Retryable reads automatically retry read operations that fail due to transient errors:

```javascript
// Retryable read (enabled by default)
db.orders.find({ status: "shipped" });
```

**Retryable read requirements:**
- The operation must be a single read (not part of a multi-document transaction).
- The read concern must be `local` or `available` (not `majority` or `linearizable`).

### Error Handling

Even with retryable reads/writes, applications should still handle non-retryable errors:

```javascript
try {
  db.orders.insertOne({ item: "Widget" }, { writeConcern: { w: "majority" } });
} catch (error) {
  if (error.hasErrorLabel("RetryableWriteError")) {
    // Driver already retried once and still failed
    // Log and alert
  } else {
    // Non-retryable error (validation, duplicate key, etc.)
    // Handle appropriately
  }
}
```

> **Key takeaway:** Retryable reads and writes improve application resilience by automatically handling transient failures (network errors, replica set elections) without requiring application code changes, especially valuable in distributed and cloud environments.

---

## 9. Collection Methods

MongoDB collections provide comprehensive methods for data manipulation, index management, and administrative functions.

### CRUD Methods

| Method                  | Description                              |
|-------------------------|------------------------------------------|
| `insertOne(document)`   | Inserts a single document                |
| `insertMany([documents])`| Inserts multiple documents              |
| `findOne(filter)`       | Returns one matching document            |
| `find(filter)`          | Returns a cursor to matching documents   |
| `updateOne(filter, update)`| Updates one matching document         |
| `updateMany(filter, update)`| Updates all matching documents       |
| `replaceOne(filter, replacement)`| Replaces one matching document   |
| `deleteOne(filter)`     | Deletes one matching document            |
| `deleteMany(filter)`    | Deletes all matching documents           |
| `countDocuments(filter)`| Counts matching documents                |
| `distinct(field, filter)`| Returns distinct values for a field     |

### Index Management Methods

| Method                  | Description                              |
|-------------------------|------------------------------------------|
| `createIndex(keys, options)`| Creates an index on specified fields   |
| `createIndexes([indexes])`| Creates multiple indexes                 |
| `dropIndex(name)`       | Drops a specific index                   |
| `dropIndexes()`         | Drops all indexes except `_id`           |
| `getIndexes()`          | Returns all indexes on the collection    |
| `getIndexStats()`       | Returns index statistics                 |

### Collection Administration Methods

| Method                  | Description                              |
|-------------------------|------------------------------------------|
| `drop()`                | Drops the entire collection              |
| `bulkWrite([operations])`| Performs bulk write operations          |
| `aggregate([pipeline])` | Runs an aggregation pipeline             |
| `mapReduce(map, reduce, options)`| Performs map-reduce operations   |

### Example: Collection Methods in Practice

```javascript
// Create indexes
db.users.createIndex({ email: 1 });                    // Ascending index on email
db.users.createIndex({ age: -1 });                     // Descending index on age
db.users.createIndex({ tags: 1 });                     // Index on array field
db.users.createIndex({ name: "text" });                // Text index for search
db.users.createIndex({ email: 1 }, { unique: true });  // Unique index

// Bulk write operations
db.users.bulkWrite([
  { insertOne: { document: { name: "Dave", age: 28 } } },
  { updateOne: { filter: { name: "Alice" }, update: { $set: { age: 31 } } } },
  { deleteOne: { filter: { name: "Bob" } } }
]);

// Count documents
const total = db.users.countDocuments({});
const adults = db.users.countDocuments({ age: { $gte: 18 } });

// Distinct values
const cities = db.users.distinct("city");

// Drop an index
db.users.dropIndex("email_1");

// Drop collection
db.tempCollection.drop();
```

### Index Types

| Index Type   | Use Case                    | Example                 |
|--------------|-----------------------------|-------------------------|
| Single field | Queries on one field        | `{ age: 1 }`            |
| Compound     | Queries on multiple fields  | `{ last_name: 1, first_name: 1 }` |
| Multikey     | Array fields                | `{ tags: 1 }`           |
| Geospatial   | Location-based queries      | `{ location: "2dsphere" }` |
| Text         | Text search                 | `{ description: "text" }` |
| Hashed       | Sharding, equality matches  | `{ _id: "hashed" }`     |
| TTL          | Auto-expire documents       | `{ createdAt: 1 }` (expireAfterSeconds) |

> **Key takeaway:** Collection methods provide the full spectrum of data operations — CRUD, indexing, aggregation, and bulk writes — enabling efficient data access and maintenance in MongoDB.

---

## 10. Aggregation Framework

MongoDB's aggregation framework is a powerful data processing pipeline that transforms documents through sequential stages. Each stage performs a specific operation and passes results to the next stage.

### Pipeline Concept

```text
Input Documents → $match → $group → $project → $sort → Output Documents
```

Each stage is an operator that takes documents as input and produces documents as output.

### Core Aggregation Stages

| Stage   | Purpose                        | Example                                                                     |
|---------|--------------------------------|-----------------------------------------------------------------------------|
| `$match`| Filter documents               | `{ $match: { status: "active" } }`                                          |
| `$group`| Group and aggregate            | `{ $group: { _id: "$category", total: { $sum: "$price" } } }`              |
| `$project`| Select/reshape fields         | `{ $project: { name: 1, price: 1, _id: 0 } }`                               |
| `$sort` | Order results                  | `{ $sort: { price: -1 } }`                                                  |
| `$limit`| Limit number of documents      | `{ $limit: 10 }`                                                            |
| `$skip` | Skip documents                 | `{ $skip: 20 }`                                                             |
| `$lookup`| Join with another collection  | `{ $lookup: { from: "orders", localField: "_id", foreignField: "user_id", as: "orders" } }` |
| `$unwind`| Deconstruct arrays            | `{ $unwind: "$tags" }`                                                      |
| `$addFields`| Add new fields              | `{ $addFields: { full_name: { $concat: ["$first_name", " ", "$last_name"] } } }` |
| `$count` | Count documents               | `{ $count: "total" }`                                                       |

### Common Aggregation Operators

| Category   | Operators                                          | Examples                                                 |
|------------|----------------------------------------------------|----------------------------------------------------------|
| Arithmetic | `$add`, `$subtract`, `$multiply`, `$divide`, `$mod`| `{ $add: ["$price", "$tax"] }`                           |
| Comparison | `$eq`, `$gt`, `$gte`, `$lt`, `$lte`, `$ne`          | `{ $gt: ["$age", 25] }`                                  |
| Array      | `$push`, `$addToSet`, `$first`, `$last`, `$max`, `$min`| `{ $push: "$tags" }`                                   |
| String     | `$concat`, `$toLower`, `$toUpper`, `$substr`        | `{ $concat: ["$first", " ", "$last"] }`                  |
| Date       | `$year`, `$month`, `$day`, `$dateToString`          | `{ $year: "$created_at" }`                               |
| Conditional| `$cond`, `$ifNull`, `$switch`                      | `{ $cond: { if: { $gt: ["$score", 90] }, then: "A", else: "B" } }` |

### Example Aggregation Pipelines

**Example 1: Total sales by category**

```javascript
db.sales.aggregate([
  { $match: { status: "completed" } },
  { $group: {
      _id: "$category",
      totalSales: { $sum: "$amount" },
      avgOrder: { $avg: "$amount" },
      orderCount: { $sum: 1 }
    }
  },
  { $sort: { totalSales: -1 } }
]);
```

**Example 2: Users with their orders (lookup join)**

```javascript
db.users.aggregate([
  { $match: { active: true } },
  {
    $lookup: {
      from: "orders",
      localField: "_id",
      foreignField: "user_id",
      as: "user_orders"
    }
  },
  { $unwind: { path: "$user_orders", preserveNullAndEmptyArrays: true } },
  { $project: {
      name: 1,
      email: 1,
      order_id: "$user_orders._id",
      order_total: "$user_orders.total"
    }
  }
]);
```

**Example 3: Monthly revenue with date operators**

```javascript
db.sales.aggregate([
  { $match: { status: "completed" } },
  {
    $group: {
      _id: { year: { $year: "$date" }, month: { $month: "$date" } },
      revenue: { $sum: "$total" },
      transactions: { $sum: 1 }
    }
  },
  { $sort: { "_id.year": -1, "_id.month": -1 } }
]);
```

### Aggregation Performance

- `$match` and `$sort` should appear early in the pipeline when possible, as they can use indexes.
- `$group` and `$sort` may require memory; use `$limit` to reduce document volume before expensive stages.
- The `$lookup` stage performs a join and can be expensive on large collections; ensure the foreign field is indexed.

> **Key takeaway:** The aggregation pipeline transforms documents through sequential stages (`$match`, `$group`, `$project`, `$sort`, `$lookup`, `$unwind`, etc.), enabling complex analytics, reporting, and ETL directly within MongoDB without exporting data.

---

## 11. MongoDB Architecture: Replica Sets and Sharding

This section explores MongoDB's distributed architecture — how it scales horizontally and maintains high availability.

### Replica Sets

A **replica set** is a group of MongoDB instances that maintain the same data set, providing automatic failover and data redundancy.

```text
Replica Set Architecture:
    Primary ──────────┐
      │               │
      │ replicates to │
      ↓               ↓
    Secondary ───→ Secondary
   (reads, failover)
```

**Replica set members:**
- **Primary**: Receives all write operations. Only one primary at a time.
- **Secondary**: Replicates data from the primary. Can serve read operations (if configured).
- **Arbiter**: Participates in elections but holds no data. Used to break ties in voting.

**Failover process:**
1. If the primary becomes unavailable, secondaries hold an election.
2. A new primary is elected.
3. Applications automatically reconnect to the new primary (driver handles reconnection).
4. Writes resume on the new primary.

### Sharding

**Sharding** is MongoDB's approach to horizontal scaling — distributing data across multiple machines.

```text
Sharded Cluster Architecture:
     ┌─────────────┐
     │ Config Servers│  ← Stores cluster metadata
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │  Mongos Router │  ← Query router for applications
     └──────┬──────┘
            │
     ┌──────┼──────┐
     ↓      ↓      ↓
  Shard 1  Shard 2  Shard 3
  (replica   (replica   (replica
   set)       set)       set)
```

**Sharding components:**
- **Shard**: A replica set that holds a subset of the data.
- **Config servers**: Store the cluster's metadata (chunk mapping, configuration).
- **Mongos**: Query router that directs client operations to the appropriate shard.

**Shard key selection:**
- The shard key determines how data is distributed across shards.
- A good shard key has high cardinality, even write distribution, and supports common query patterns.
- Once chosen, the shard key cannot be changed without resharding.

### Read Preferences

Read preference determines where read operations are directed in a replica set or sharded cluster:

| Read Preference     | Description                                        |
|---------------------|----------------------------------------------------|
| `primary`           | Reads from primary only (default, strongest consistency) |
| `primaryPreferred`  | Primary if available, otherwise secondary          |
| `secondary`         | Reads from secondary only                          |
| `secondaryPreferred`| Secondary if available, otherwise primary          |
| `nearest`           | Reads from the member with lowest network latency  |

```javascript
// Read from secondary for better read throughput
db.users.find().readPreference("secondary");

// Read from primary for strong consistency
db.users.find().readPreference("primary");
```

### Write Concerns in Replica Sets

```javascript
// Wait for majority of replica set to acknowledge
db.users.insertOne(
  { name: "Alice" },
  { writeConcern: { w: "majority", j: true } }
);

// Wait for all voting members
db.users.insertOne(
  { name: "Bob" },
  { writeConcern: { w: "all" } }
);
```

> **Key takeaway:** MongoDB scales horizontally through sharding (data partitioning across shards) and maintains high availability through replica sets (automatic failover with primary/secondary nodes). Read preferences and write concerns let you tune consistency and performance per operation.

---

## 12. MongoDB Cheat Sheet

| Concept               | Command / Syntax                                   |
|-----------------------|----------------------------------------------------|
| Start mongo shell     | `mongosh` or `mongo`                               |
| Show databases        | `show dbs`                                         |
| Use database          | `use lab_6020`                                     |
| Show collections      | `show collections`                                 |
| Insert one            | `db.collection.insertOne({...})`                   |
| Insert many           | `db.collection.insertMany([...])`                  |
| Find all              | `db.collection.find()`                             |
| Find with filter      | `db.collection.find({ field: value })`             |
| Find one              | `db.collection.findOne({...})`                     |
| Update one            | `db.collection.updateOne({...}, { $set: {...} })`  |
| Update many           | `db.collection.updateMany({...}, { $set: {...} })` |
| Delete one            | `db.collection.deleteOne({...})`                   |
| Delete many           | `db.collection.deleteMany({...})`                  |
| Create index          | `db.collection.createIndex({ field: 1 })`          |
| Drop index            | `db.collection.dropIndex("name")`                  |
| Aggregate             | `db.collection.aggregate([...])`                   |
| Count                 | `db.collection.countDocuments({...})`              |
| Distinct              | `db.collection.distinct("field")`                  |
| Bulk write            | `db.collection.bulkWrite([...])`                   |
| Drop collection       | `db.collection.drop()`                             |

### Query Operators

| Operator    | Meaning              |
|-------------|----------------------|
| `$eq`, `$gt`, `$gte`, `$lt`, `$lte`, `$ne` | Comparison       |
| `$in`, `$nin` | Array membership     |
| `$and`, `$or`, `$not` | Logical         |
| `$exists`   | Field existence      |
| `$regex`    | Pattern matching     |
| `$set`      | Set field value (update) |
| `$inc`      | Increment numeric field (update) |
| `$push`, `$pull` | Array modification (update) |
| `$unset`    | Remove field (update) |

### Aggregation Stages

| Stage     | Purpose                  |
|-----------|--------------------------|
| `$match`  | Filter documents         |
| `$group`  | Group and aggregate      |
| `$project`| Reshape documents        |
| `$sort`   | Order results            |
| `$limit`  | Limit document count     |
| `$skip`   | Skip documents           |
| `$lookup` | Join collections         |
| `$unwind` | Expand arrays            |
| `$addFields`| Add computed fields     |
| `$count`  | Count documents          |

### Read/Write Concerns

| Setting          | Values                                               | Purpose                              |
|------------------|------------------------------------------------------|--------------------------------------|
| Write concern    | `w: 0`, `w: 1`, `w: "majority"`, `w: "all"`, `j: true` | Write acknowledgment durability     |
| Read concern     | `local`, `available`, `majority`, `linearizable`, `snapshot` | Read consistency level           |
| Read preference  | `primary`, `primaryPreferred`, `secondary`, `secondaryPreferred`, `nearest` | Read routing in replica sets |

### CAP and Consistency

| Guarantee | MongoDB Default | Tunable Via                   |
|-----------|-----------------|-------------------------------|
| Consistency | CP (during partitions) | Read/write concern       |
| Availability | Reduced during partition | Read preference (secondary) |
| Partition tolerance | Yes (distributed architecture) | Replica sets, sharding |

> **Key takeaway:** MongoDB provides a flexible document model with powerful querying, aggregation, and distributed architecture. Tuning read/write concerns and read preferences lets you balance consistency, availability, and performance for your specific workload.

---