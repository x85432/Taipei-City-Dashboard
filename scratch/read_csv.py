import csv

def process():
    try:
        with open('113年-臺北市A1及A2類交通事故明細.csv', 'r', encoding='cp950') as f:
            reader = csv.reader(f)
            for i, row in enumerate(reader):
                print(row)
                if i >= 5:
                    break
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    process()
