import sys
print("Python Path đangប្រើ:", sys.executable)

try:
    import pysrt
    print("ជោគជ័យ! រកឃើញ pysrt រួចរាល់។")
except ImportError:
    print("ខុសហើយ! នៅតែរកមិនឃើញ pysrt។")