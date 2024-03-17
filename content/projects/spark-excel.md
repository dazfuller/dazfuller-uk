+++
title = 'Spark Excel'
date = 2024-03-17T11:27:04Z
draft = true
tags = ['open source', 'spark', 'excel', 'scala']
disable_share = true
+++
## What is it?

I think I might be cursed. Most projects I end up working on seem to involve getting data out of Excel at some point! So, in an effort to make this all a bit easier (and because I wanted learn how Spark data source worked), I wrote this library to read data in from Excel as a data source directly, rather than needing to use something like Pandas.

Whilst I was at it, I wanted to add some other features in which I felt were missing elsewhere, like being able to load in multiple sheets from the same workbook which match a given regex. Loading multiple workbooks. Handling merged cells in headers and a few more.

Check out the code over at [Github](https://github.com/elastacloud/spark-excel "Spark Excel")!
