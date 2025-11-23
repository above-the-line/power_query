

// =======================================
//
//
// Fill down function 
//
//
// =======================================

// Custom function to fill down rows except specified columns
// Say you want to build 12 unique months of values, from a starting point of just 12 rows.
// You start with 12 rows and you end with 365, with your initial 12 being the sample to copy 30 times in each respective month.
// One approach to solving this is to build a date table (365 rows), join on your specific target values, and then "fill the gaps".
// For this you would need a "copy down" function that fills down the first value of the month for all remaining days of that month.
// In the code below, I assume you already have a table with 365 rows and 12 target "bookending" or "marker" rows that needs to be copied down for each month.
// The copy down function is build to copying all values except the date, and keep copying down until it finds the next "marker" row.
// (another row where the date column has a value that is not null)
let
    FillDown = (table as table) as table =>
        let
            columnNames = Table.ColumnNames(table),
            rows = Table.ToRows(table),
            filledRows = List.Accumulate(
                List.Skip(rows, 1),
                {List.First(rows)},
                (state, currentRow) =>
                    let
                        previousRow = List.Last(state),
                        newRow = List.Transform(
                            {0..List.Count(columnNames) - 1},
                            (i) =>
                                if currentRow{i} = null and not List.Contains({"Date"}, columnNames{i}) then
                                    previousRow{i}
                                else
                                    currentRow{i}
                        )
                    in
                        state & {newRow}
            ),
            filledTable = Table.FromRows(filledRows, columnNames)
        in
            filledTable,
    #"previousStepInEtl" = source,
    // Apply FillDown function
    #"Filled Down" = FillDown(#"previousStepInEtl"),
    #"Sorted Rows1" = Table.Sort(#"Filled Down", {{"Date", Order.Ascending}})
in
    #"Sorted Rows1"




// =======================================
//
//
// Fill down function : generic
//
//
// =======================================

// Generic FillDown function
// Fills down values for all columns EXCEPT the ones you specify.
// Fills down until the next "marker row" (i.e., a non-null value in any column).
//
// Parameters:
//   sourceTable     – the table to operate on
//   noFillColumns   – list of column names that should NOT be filled down
//
// Behaviour:
//   For each row, if a column value is null AND that column is not in noFillColumns,
//   the value from the previous row is copied down.



// Using it
// FilledDown =
//     FillDownGeneric(
//         #"previousStepInEtl",
//         {"Date"}     // ← columns NOT to fill down
//     ),

// Sorted =
//     Table.Sort(FilledDown, {{"Date", Order.Ascending}})


FillDownGeneric = (sourceTable as table, noFillColumns as list) as table =>
let
    columnNames = Table.ColumnNames(sourceTable),
    rows = Table.ToRows(sourceTable),

    filledRows =
        List.Accumulate(
            List.Skip(rows, 1),
            { List.First(rows) },
            (state, currentRow) =>
                let
                    prev = List.Last(state),
                    newRow =
                        List.Transform(
                            {0 .. List.Count(columnNames) - 1},
                            (i) =>
                                let col = columnNames{i} in
                                if currentRow{i} = null and not List.Contains(noFillColumns, col)
                                then prev{i} 
                                else currentRow{i}
                        )
                in
                    state & { newRow }
        ),

    filledTable = Table.FromRows(filledRows, columnNames)
in
    filledTable







// =======================================
//
//
// Target, tag, mutate and cooy
//
//
// =======================================


// Say I want to target all rows with a particular value in a particular column and then mark that the row has been found
// then make a copy of the row and mutate some of the values.
// This generic function does that. It replicates each row of a source table for each value 
// in a supplied list, applying custom transformations to fields.

let 
    ReplicateRows = (sourceTable as table) as table =>
        let 
            targetValues = { "value1", "value2", "etc"}, 
            // Generate the replicated rows 
            replicatedRows = List.Transform( Table.ToRecords(sourceTable), 
            // Convert table to list of records 
            (currentRow) => List.Transform( targetValues, 
                (valueInTarget) => 
                    let 
                        paramToCheck = Record.Field(currentRow, "columnToTarget"), 
                        conditionalValue = if paramToCheck = "XYZ" then "ABC" else "DEF", 
                        newRow = Record.TransformFields( currentRow, { 
                            {"metricOne", each conditionalValue},
                            {"columnToTargetTag", each "PowerBI Generated Row"}, 
                            {"columnNumberValue", each Decimal.From(_ / List.Count(targetValues))}, 
                            {"Bus_orgPathTxt", each Text.Format("#{0}/#{1}", {"PowerBIGenerated", valueInTarget})} 
                        } ) 
                    in 
                        newRow 
                ) 
            ), 
            // Flatten the list of lists and create the final table 
            finalTable = Table.FromRecords(List.Combine(replicatedRows), Table.ColumnNames(sourceTable)) 
        in 
            finalTable, 
    // Apply ReplicateRows function to the expanded table 
    #"TargetTagMutateCopy" = ReplicateRows(#"Renamed Columns")
in 
    #"TargetTagMutateCopy"












// =======================================
//
//
// Target, tag, mutate and cooy : Generic
//
//
// =======================================




// Say I want to target all rows with a particular value in a particular column and then mark that the row has been found
// then make a copy of the row and mutate some of the values.
// This generic function does that. It replicates each row of a source table for each value 
// in a supplied list, applying custom transformations to fields.
//
// Parameters:
//   sourceTable        – the original table
//   replicationValues  – list of values to replicate by (e.g., cost centre codes)
//   transformPerRecord – function(record, value) => record, returns transformed record
//
// Returns:
//   A table where each original row is replicated once per replication value,
//   with custom transformations applied.

ReplicateRows = (
    sourceTable as table,
    replicationValues as list,
    transformPerRecord as function
) as table =>
let
    // Convert to list of source records
    sourceRecords = Table.ToRecords(sourceTable),

    // Produce replicated + transformed records
    replicated =
        List.Combine(
            List.Transform(
                sourceRecords,
                (row) =>
                    List.Transform(
                        replicationValues,
                        (val) => transformPerRecord(row, val)
                    )
            )
        ),

    // Convert back to table (assumes same schema as input)
    output = Table.FromRecords(replicated, Table.ColumnNames(sourceTable))
in
    output
