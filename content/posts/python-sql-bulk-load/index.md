+++
title = 'Azure SQL - Bulk Loading from Python'
date = 2025-01-18T13:07:29Z
tags = ['python', 'large-files', 'bulk-data']
featured_image = 'loading-plane.webp'
+++
I seem to be dealing with a number of instances lately where I have to get a lot of data into SQL. Most of job involves doing this in various Big Data solutions hosted in the cloud where this happens pretty well at scale, using things like [Spark](https://spark.apache.org), [Azure Data Factory](https://learn.microsoft.com/azure/data-factory/introduction), or [Azure Fabric](https://learn.microsoft.com/fabric/get-started/microsoft-fabric-overview). But recently I've needed to do this from local devices to instances of [Azure SQL](https://learn.microsoft.com/azure/azure-sql/azure-sql-iaas-vs-paas-what-is-overview), which is fine but there's some limitation.

1. Azure SQL doesn't get a lot of the bulk load features of the Warehouse versions
2. It has the ability to connect to services like Azure Blob, but it's kind of rubbish (when it works)
3. Format files - Seriously, it's 2025 (at the time of writing) and we still have those!

So what options do we have for loading in data?

By the way. You can find all of the code presented here [online](https://codeberg.org/dazfuller/python-sql-bulk-load)

## Breaking down the options.

I need to do this in a way which can run from a client machine, which might be a laptop, desktop, on-premise VM etc... So I need to use options available to the language, and not rely on 3rd party software or services, other than the database I'm trying to push the data to. That basically leaves me with different options for using SQL directly. So what are they?

1. Plain old insert statements
2. Bulk load using the `executemany` command
3. Table-Value Parameters

To test this out I created a really simple Python application which loads information about [local authority owned trees in Camden](https://www.data.gov.uk/dataset/7920409f-4a05-40c6-8946-0cbb1b5252bf/trees-in-camden).

Yes, this is a thing.

No, I don't know why.

Look, I needed data, this is data, and it's not the usual boring stock market or web search data. Feel free to try something else out if you don't like trees!

Seriously, who doesn't like trees! (Obligatory comic from [The Oatmeal](https://theoatmeal.com/comics/tree_love))

![Tree Love](oatmeal-tree-love.webp "The Oatmeal - Tree Love")

Right, back to trees.

I downloaded the CSV version of the data and put something together quickly which could load each row of data into a [data class](https://docs.python.org/3/library/dataclasses.html) and returns all the records as a list of this data class.

```python
@dataclass
class TreeData:
    number_of_trees: int
    sequence: float
    site_name: str
    contract_area: str
    scientific_name: str
    common_name: str
    inspection_date: Optional[str]
    inspection_due_date: Optional[str]
    height_in_metres: Optional[float]
    spread_in_metres: Optional[float]
    diameter_in_cm_at_breast_height: Optional[float]
    maturity: str
    physiological_condition: str
    tree_set_to_be_removed: str
    removal_reason: Optional[str]
    newly_planted: Optional[str]
    outstanding_job_count: Optional[int]
    outstanding_job_number: Optional[str]
    outstanding_job_description: Optional[str]
    capital_asset_value_for_amenity_trees: Optional[float]
    carbon_storage_in_kg: Optional[float]
    gross_carbon_sequestration_per_year_in_kg: Optional[float]
    pollution_removal_per_year_in_grams: Optional[float]
    ward_code: str
    ward_name: str
    easting: int
    northing: int
    longitude: Optional[float]
    latitude: Optional[float]
    location: str
    identifier: str
    spatial_accuracy: str
    last_uploaded: Optional[datetime]
    organisation_uri: str
```

I then created a SQL table for the data to be inserted into, with an auto-incrementing id field.

```sql
CREATE TABLE tree_data
(
    [id] INT NOT NULL IDENTITY(1, 1)
    , number_of_trees INT NOT NULL
    , [sequence] FLOAT NOT NULL
    , site_name NVARCHAR(255) NOT NULL
    , contract_area NVARCHAR(255) NOT NULL
    , scientific_name NVARCHAR(255) NOT NULL
    , common_name NVARCHAR(255) NOT NULL
    , inspection_date DATETIME2 NULL
    , inspection_due_date NVARCHAR(20) NULL
    , height_in_metres FLOAT NULL
    , spread_in_metres FLOAT NULL
    , diameter_in_cm_at_breast_height FLOAT NULL
    , maturity NVARCHAR(50) NOT NULL
    , physiological_condition NVARCHAR(50) NOT NULL
    , tree_set_to_be_removed NVARCHAR(50) NOT NULL
    , removal_reason NVARCHAR(50) NULL
    , newly_planted NVARCHAR(50) NULL
    , outstanding_job_count INT NULL
    , outstanding_job_number NVARCHAR(50) NULL
    , outstanding_job_description NVARCHAR(255) NULL
    , capital_asset_value_for_amenity_trees FLOAT NULL
    , carbon_storage_in_kg FLOAT NULL
    , gross_carbon_sequestration_per_year_in_kg FLOAT NULL
    , pollution_removal_per_year_in_grams FLOAT NULL
    , ward_code NVARCHAR(50) NOT NULL
    , ward_name NVARCHAR(255) NOT NULL
    , easting INT NOT NULL
    , northing INT NOT NULL
    , longitude FLOAT NULL
    , latitude FLOAT NULL
    , [location] NVARCHAR(255) NOT NULL
    , identifier NVARCHAR(50) NOT NULL
    , spatial_accuracy NVARCHAR(100) NOT NULL
    , last_uploaded DATETIME2 NOT NULL
    , organisation_uri NVARCHAR(255) NOT NULL
);
```

I had to do some messing around with the data as reading the content things like dates come out as strings, and I want them as actual date and time values, but they're held in `dd/MM/yyyy` format and the time component is `HH:mm AM/PM`. As mentioned above, you can find all of the code for this [online](https://codeberg.org/dazfuller/python-sql-bulk-load).

## Running the tests

Then I created 3 functions for each of the options above to insert the 25060 records. Between each test I truncated the table so each run starts from scratch, this also resets the auto-incrementing id resulting in each load ending with the same data. Each method creates it's own connection which is using the `AzureCliCredential` option, this gets included in the final timings and can take a couple of seconds, but each method creates the connection only once. Lets see what happened.

### Plain old insert

Given that there are several thousand records here, and I know that adding them all in a single transaction is not that great, I implemented this as a simple insert statement which commits every 100 records, and then a final commit at the end. Each call of the `execute` method uses the same cursor from the connection.

It might not surprise you that this is the slowest option. Each execute has to be sent to the server, executed, and result set returned etc... If you're putting in a couple of records then this is a great option. But for 25060 records this is not great.

**Final time**: 676.8 seconds (11 minutes 16.8 seconds)

### Execute Many

Calling the `executemany` method we provide it with a list of parameter values, where each item in the list is the collection of parameters to pass to the query. This is the go-to option for many when needing to insert a lot of data quickly

Coding wise there's not a lot of changes needed here. The largest being that instead of iterating over the data rows and committing every 100 records, we pass them all in as an argument.

```python
data = [astuple(row)[0:34] for row in tree_data]
cur.executemany(stmt, data)
```

My first run took 650 seconds (10 minutes 50 seconds) which... well it's pretty bad. There's no real improvement here over the one-by-one option! But then I realised that I'd forgotten to enable the [`fast_executemany`](https://github.com/mkleehammer/pyodbc/wiki/fast_executemany-support-for-various-ODBC-drivers) option for the cursor. Enabling this is as simple as adding the following line after creating the cursor, but before calling the `executemany` method.

```python
cur.fast_executemany = True
```

If we enable that we get a very different result.

**Final time**: 7.3 seconds

### Table-Value Parameters

[Table-Value Parameters](https://learn.microsoft.com/sql/relational-databases/tables/use-table-valued-parameters-database-engine) (TVP) are declared by creating a user-defined table type in the database, allowing us to pass in a "table" of data which conforms to the table types structure. Using these we can send multiple rows of data without creating temporary tables or using multiple parameters.

I created a table type in the database which matched the structure of the target table, but without the id field (as I want the database to assign the value).

```sql
CREATE TYPE tree_data_type AS TABLE
(
    number_of_trees INT NOT NULL
    , [sequence] FLOAT NOT NULL
    -- Rest of the columns
    , last_uploaded DATETIME2 NOT NULL
    , organisation_uri NVARCHAR(255) NOT NULL
);
```

PyODBC support for table-value parameters is... interesting. Looking around the internet you go from "it's not supported" to "it sort of is". My experience is that it's closer to the "it sort of is" view. You can use them, but debugging is a pain and there are some quirks.

In the table there are these 2 columns

```sql
, removal_reason NVARCHAR(50) NULL
, newly_planted NVARCHAR(50) NULL
```

Both of them a `NVARCHAR(50)` and both accept `NULL` values. During implementation I kept getting the following error come up.

`'HY090', Invalid string or buffer length (0)`

So I had to change the table and the table type and build it back up a few columns at a time until I got to the ones causing the issues. And that's where I got to these 2. In the data on the first record both of these had a a null value in the source, which read from CSV resulted in a `None` value being passed in, and I know PyODBC correctly handles that conversion. But when using the TVP option the first column was fine, but the second column threw the error.

Why? I have no idea. In the end I changed the code to use an empty string instead of `None` and then changed the insert command to set the value to `NULL` if the string was empty, otherwise it would use the actual string. I had a few more with the float and integer columns when handling null values as well.

After all the messing about with the code I was able to execute it and get all 25060 records into the database.

**Final time**: 4.9 seconds

## Final results

Total times for loading 25060 records into an Azure SQL database.

Azure SQL DB SKU: General Purpose - Serverless: Gen5, 2 vCores

| Option               | Result (seconds) |
|----------------------|-----------------:|
| Plain old insert     |            676.8 |
| `executemany`        |              7.3 |
| Table-Value Paramter |              4.9 |

In all the table-value parameter option was the winner here, though with the amount of effort needed to get it working, is it worth the 2.4 seconds improvement? Well that very much depends on your use case, if sub 10 seconds is fine then the extra effort probably isn't. But if you want this as fast as possible then it probably is.

Using just insert statements was never going to be a close contender here. The way they work makes them too slow for bulk operations, but perfect for the typical use cases you'd have day-to-day.

One of the really annoying things with all of this though is the amount of effort needed to make all of this work. I also wrote a version of this in C# running on net9.0 where reading the file and writing to the database using the [`SqlBulkCopy` class](https://learn.microsoft.com/dotnet/api/microsoft.data.sqlclient.sqlbulkcopy) was slightly more performant, but took a fraction of the effort to write. So if performance is important, maybe don't use Python (/me runs and takes cover).

Oh, and if anyone wanted to know. The most common tree in Camden is the [London Plane(Platanus x hispanica)](https://en.wikipedia.org/wiki/London_plane) with 3337 trees.