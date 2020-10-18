from datetime import datetime
import MetaTrader5 as mt5
import numpy as np
from numpy import savez_compressed

MAX_DATA_LENGTH = 1000000
MT5_CHUNK_SIZE = 99000
INPUT_STARTDATE = datetime(2020, 10, 2, 19)
INPUT_TIMEFRAME = mt5.TIMEFRAME_M15
INPUT_SYMBOL = 'EURUSD'


mt5.initialize()

rates = mt5.copy_rates_from(
    INPUT_SYMBOL, INPUT_TIMEFRAME, INPUT_STARTDATE, MT5_CHUNK_SIZE)

while len(rates) < MAX_DATA_LENGTH:
    rates = np.concatenate((rates, mt5.copy_rates_from(INPUT_SYMBOL, INPUT_TIMEFRAME, rates[0]['time'] - 100, MT5_CHUNK_SIZE)))

err=mt5.last_error()
mt5.shutdown()

print('ERROR', err)

savez_compressed(INPUT_SYMBOL + '_'+mt5.TIMEFRAME_M15 +
                 '_' + MAX_DATA_LENGTH + '.npz', rates)
