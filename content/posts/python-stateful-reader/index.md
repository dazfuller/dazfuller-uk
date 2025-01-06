+++
title = 'Python Stateful Reader'
date = 2025-01-05T12:08:44Z
tags = ['python', 'large-files']
+++
Recently I needed to read a very large file of input data and, for each record, perform an HTTP request to send that data off somewhere else.

There's a few ways to do this. The first and simplest one is to read all of the lines from the file and then iterate over them, this has one big drawback however. In testing it worked fine, but when you scale this up to a few million records then you start to run into memory limitations! Okay, I need to look at another option.

Fairly simple next step on this one, instead of reading all of the lines, I can just use an iterator and read each line, do the work, move on to the next one. Now I don't have any more memory issues :partying_face:

But...

I left my laptop alone, it went to sleep, and then the entire thing crashed. This is an early state so no massive issue here, but if I run this over everything for real then I'm going to mess things up by now having to re-read all the content again :unamused:

I spent a little more time thinking and finally figured that the iterator approach is the right one, but I need to hold onto my progress between runs. And I kind of need to do this for different input files (also, many millions of records each). So I implemented a stateful reader.

## Options

I need to keep a record of my position for each file I process. So I can't use a single text file (or, I could, but it's not great) as I'd need to scan the file and find the row with my files position, then update that line. It's a lot of I/O work.

I could use a dotfile for each input file. So if I'm processing "sample_1m_input.txt" then I could create something like ".sample_1m_input.txt", but I don't want to litter up my folder with lots of additional files.

Okay, third option, I could use a simple table in a database to do this. I don't want extra network traffic so I could use [sqlite3](https://docs.python.org/3/library/sqlite3.html) instead. I would only need a single table that holds my input file and it's current position.

I choose to go for option 3.

## Implementation

I implemented a wrapper class for all of the logic, so I can just give it the file, some options, and then start reading data, and let it handle the hard work. There are a few extra requirements I had though.

1. I don't want to record the state after reading each record. This is because I want to reduce my HTTP traffic in the other part of the code base, so I'm sending 50 records at a time in a single HTTP request. If that HTTP request fails and I've captured the position after each read, then I'll lose those records. Instead what I want to do is read 50, do the extra work, and if all is good, then I want to checkpoint where I am before I move on to the next batch.
2. I also want a way to be able to reset my file position, in case I actually do want to re-process it.

Right, on to the code.

First up, lets create the class.

By the way, if you're following along, then you'll want these import statements at the top of the code file.

```python
import sqlite3
from io import SEEK_SET
from sqlite3.dbapi2 import Cursor
from typing import Iterable, TextIO, Union
```

First up, I want to create a new instance from a file path and I need to know the encoding (some of the files aren't plain old utf-8)

```python
class StatefulReader:
    def __init__(self, file_path: str, encoding: str = 'utf-8'):
        self._file_path = file_path
        self._encoding = encoding
        self._file_reader: Union[TextIO, None] = None
        self._state_file = ".state.db"
        self._state_connection: Union[sqlite3.Connection, None] = None
```

I'm capturing the file path and encoding for later on. There's a `_file_reader` which I'll be using later when I open the file along with the database connection. Before I move on to reading the file though, I need to implement a few more things.

I want to use this as a context manager, or using a `with` statement. This way I can make sure that the database and reader are cleared down correctly after use.

```python
def __enter__(self):
    self._file_reader = open(self._file_path, "r", encoding=self._encoding)
    return self

def __exit__(self, exc_type, exc_val, exc_tb):
    self._file_reader.close()
    self._state_connection.close()
    self._file_reader = None

def _initialize_state(self) -> None:
    """Initializes the state table if it doesn't exist."""
    cursor: Cursor = self._state_connection.cursor()
    cursor.execute("CREATE TABLE IF NOT EXISTS state (file TEXT PRIMARY KEY, position INTEGER)")
    cursor.close()
```

Here I'm setting the reader by opening the file, and in the exit I'm closing it. There's also an initialization method in here which creates the table if it doesn't exist in the database. This way if I delete the database or deploy this somewhere else then I don't need to manually create anything. I'm also using write-ahead logging here for performance.

There are 2 more methods I'm going to need which are internal to the class. The first is to get the latest position read to for the file, and another to save the current position.

```python
def _get_latest_position(self) -> int:
    cursor: Cursor = self._state_connection.cursor()
    cursor.execute("SELECT position FROM state WHERE file = ?", (self._file_path,))
    row = cursor.fetchone()
    cursor.close()
    if row is None:
        return 0
    else:
        return row[0]

def _save_position(self, position: int) -> None:
    cursor: Cursor = self._state_connection.cursor()
    cursor.execute("INSERT OR REPLACE INTO state VALUES (?, ?)", (self._file_path, position))
    self._state_connection.commit()
    cursor.close()
```

In the `_get_latest_position` method I'm simply selecting the position for the file from the database. The value is the offset from the start of the file, so if I don't have any records then I default the response to 0.

The `_save_position` takes a position and then writes it to the database. It's using an "INSERT OR REPLACE" here so that it overwrites the record if it exists, or inserts it if it doesn't.

Both of these are using parameterised queries and using the file path as intended. The reason for using the path and not the file name is in case I wanted to run this against 2 files with the same name but which are in different locations.

Okay, now for the methods that the client code is going to need to use. First lets implement methods to save the position and reset it.

```python
def reset_to_start(self) -> None:
    self._save_position(0)

def checkpoint(self) -> None:
    self._save_position(self._file_reader.tell())
```

These are insanely simple. To reset I just update the saved position to 0, and to checkpoint I get to current offset from the reader and save it. Now, on to the iterator.

```python
def read_lines(self) -> Iterable[str]:
    if self._file_reader is None:
        raise Exception("StatefulReader must be used as a context manager.")

    self._file_reader.seek(self._get_latest_position(), SEEK_SET)
    while True:
        line = self._file_reader.readline()
        if not line:
            break
        yield line.strip()
```

As you can see here, if you try using the `read_lines` method outside of being a context manager it will raise an error. The next line is probably the most complex here (and it's not very complex), in that it gets the latest position for the file, and then tells the reader to seek to that location.

By using the offset here we can avoid having to perform costly calculations like recording the number of lines read. Working this way means we can use the features built in already.

And this is it. If you want the full code then it looks as follows:

```python
import sqlite3
from io import SEEK_SET
from sqlite3.dbapi2 import Cursor
from typing import Iterable, TextIO, Union


class StatefulReader:
    def __init__(self, file_path: str, encoding: str = 'utf-8'):
        self._file_path = file_path
        self._encoding = encoding
        self._file_reader: Union[TextIO, None] = None
        self._state_file = ".state.db"
        self._state_connection: Union[sqlite3.Connection, None] = None

    def __enter__(self):
        self._state_connection = sqlite3.connect(self._state_file, isolation_level=None)
        self._state_connection.execute("pragma journal_mode=wal")
        self._initialize_state()
        self._file_reader = open(self._file_path, "r", encoding=self._encoding)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._file_reader.close()
        self._state_connection.close()
        self._file_reader = None

    def reset_to_start(self) -> None:
        self._save_position(0)

    def checkpoint(self) -> None:
        self._save_position(self._file_reader.tell())

    def read_lines(self) -> Iterable[str]:
        if self._file_reader is None:
            raise Exception("StatefulReader must be used as a context manager.")

        self._file_reader.seek(self._get_latest_position(), SEEK_SET)
        while True:
            line = self._file_reader.readline()
            if not line:
                break
            yield line.strip()

    def _initialize_state(self) -> None:
        """Initializes the state table if it doesn't exist."""
        cursor: Cursor = self._state_connection.cursor()
        cursor.execute("CREATE TABLE IF NOT EXISTS state (file TEXT PRIMARY KEY, position INTEGER)")
        cursor.close()

    def _get_latest_position(self) -> int:
        cursor: Cursor = self._state_connection.cursor()
        cursor.execute("SELECT position FROM state WHERE file = ?", (self._file_path,))
        row = cursor.fetchone()
        cursor.close()
        if row is None:
            return 0
        else:
            return row[0]

    def _save_position(self, position: int) -> None:
        cursor: Cursor = self._state_connection.cursor()
        cursor.execute("INSERT OR REPLACE INTO state VALUES (?, ?)", (self._file_path, position))
        self._state_connection.commit()
        cursor.close()

```

## Testing it out

Lets give it a try out. I wrote a couple of helper methods to test it out with, and created a sample input file with 1 million lines in it.

```python
def read_n_lines(reader: StatefulReader, n: int) -> None:
    count = 0
    for line in reader.read_lines():
        print(line)
        count += 1
        if count >= n:
            break


def run() -> None:
    with StatefulReader('./input/sample_1m_input.txt') as reader:
        print("Reading 10 lines from the file")
        print("==============================")
        read_n_lines(reader, 10)

        print()
        print("Reading next 10 lines from the file")
        print("===================================")
        read_n_lines(reader, 10)


if __name__ == '__main__':
    run()
```

In this first example I'm not using checkpointing, this is to prove that without it we'll go back to the start of the file.

```text
Reading 10 lines from the file
==============================
Sample entry 0
Sample entry 1
Sample entry 2
Sample entry 3
Sample entry 4
Sample entry 5
Sample entry 6
Sample entry 7
Sample entry 8
Sample entry 9

Reading next 10 lines from the file
===================================
Sample entry 0
Sample entry 1
Sample entry 2
Sample entry 3
Sample entry 4
Sample entry 5
Sample entry 6
Sample entry 7
Sample entry 8
Sample entry 9
```

Now, if we add in the checkpoint call after the first `read_n_lines(reader, 10)` line and run it again, we get this.

```text
Reading 10 lines from the file
==============================
Sample entry 0
Sample entry 1
Sample entry 2
Sample entry 3
Sample entry 4
Sample entry 5
Sample entry 6
Sample entry 7
Sample entry 8
Sample entry 9

Reading next 10 lines from the file
===================================
Sample entry 10
Sample entry 11
Sample entry 12
Sample entry 13
Sample entry 14
Sample entry 15
Sample entry 16
Sample entry 17
Sample entry 18
Sample entry 19
```

In the first call it reads 10 lines from the start of the file, then saves the checkpoint. Then in the next call we get the latest position back from our state and keep reading from there. If we check the sqlite3 database we would see the following.

```shell
❯ sqlite3 -header -box .state.db
SQLite version 3.43.2 2023-10-10 13:08:14
Enter ".help" for usage hints.
sqlite> select * from state;
┌─────────────────────────────┬──────────┐
│            file             │ position │
├─────────────────────────────┼──────────┤
│ ./input/sample_1m_input.txt │ 150      │
└─────────────────────────────┴──────────┘
```

If you try doing the same with another file then you'll get another record in the table.

> One thing to note, if you run this a number of times you'll notice that the last 10 of the previous run and the first 10 of the next run are the same records. This is because we haven't added a checkpoint after the second set, so if you were going to use this you'd want to make sure you do that.

## Using it

I plugged this into the process I was running and off I went again. This time when the process stopped (okay, I might have done it on purpose a couple of times to check this was working), I could resume the program and it would pick up from where it left off.

Job done
