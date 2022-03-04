import os
import csv
import glob
from pathlib import Path


#csv params
CSV_PATH = 'Analysis/Data/Freq_vs_params/'
CSV_REPORT_NAME = "Report_freq_vs_params.csv"
CSV_REPORT_PATH = CSV_PATH + CSV_REPORT_NAME

GLOB_EXPR = "frequencies_*.csv"
CSV_FILTER = CSV_PATH + GLOB_EXPR




report_rows = []
header = 0
for filename in glob.glob(CSV_FILTER):

    with open(filename, 'r') as r_f:
            reader = csv.reader(r_f)
            header = next(reader)

            for row in reader:
                report_rows.append(row)

with open(CSV_REPORT_PATH, 'w') as w_f:
    writer = csv.writer(w_f)
    writer.writerow(header)
    writer.writerows(report_rows)