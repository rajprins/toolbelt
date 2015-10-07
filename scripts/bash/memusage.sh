ps -axm -o 'rss,comm' | awk 'BEGIN { s=0;}; {s=s+$1;}; END { printf("%.2f GB\n", (s/1024.0/1024));}'

