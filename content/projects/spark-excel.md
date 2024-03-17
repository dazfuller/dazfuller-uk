+++
title = 'Spark Excel'
date = 2024-03-17T11:27:04Z
tags = ['open source', 'spark', 'excel', 'scala']
+++
## What is it?

I think I might be cursed. Most projects I end up working on seem to involve getting data out of Excel at some point! So, in an effort to make this all a bit easier (and because I wanted learn how Spark data source worked), I wrote this library to read data in from Excel as a data source directly, rather than needing to use something like Pandas.

Whilst I was at it, I wanted to add some other features in which I felt were missing elsewhere, like being able to load in multiple sheets from the same workbook which match a given regex. Loading multiple workbooks. Handling merged cells in headers and a few more.

With the library running on a Spark instance the user can run something similar to the following:

```scala
val df = spark.read
  .format("com.elastacloud.spark.excel")
  .option("cellAddress", "A1")
  .option("headerRowCount", 2)
  .option("includeSheetName", value = true)
  .option("sheetNamePattern", """Sheet[13]""")
  .load("/path/to/files/*.xlsx")
```

Which will load all `.xlsx` files in the directory given and, for each sheet matching the regular expression pattern `Sheet[13]`, it will read the data starting from cell `A1`, it will read the first 2 rows as the header, and from this it will read all the data. The "includeSheetName" means that a new column is added to the data frame which includes the name of the sheet the data came from, which is useful if the sheet name contains information giving the data context.

Check out the code over at [Github](https://github.com/elastacloud/spark-excel "Spark Excel")!
