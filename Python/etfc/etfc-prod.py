import sys
import os

import MetaTrader5 as mt5
import calendar
from datetime import datetime, date
import tensorflow as tf
import seaborn as sns
import pandas as pd
import numpy as np

physical_devices = tf.config.list_physical_devices('GPU')
tf.config.experimental.set_memory_growth(physical_devices[0], enable=True)

INPUT_SYMBOL = 'EURUSD'

IMAGE_LENGTH_M15 = 24
IMAGE_LENGTH_H1 = 24
IMAGE_LENGTH_H4 = 12
IMAGE_LENGTH_M5 = 12
IMAGE_LENGTH_D1 = 10

DAY = 2 * np.pi / (24*60*60)
WEEK = DAY / 7
YEAR = DAY / (365.2425)

THRESOLD_DIFF = 2
TARGET = 3

DAY_HISTORY_TO_PROCESS = 100

F_SINGLE_MEDIUM = True
F_VOLUME = True
F_REPEAT = 1
F_TIME = False
F_LABEL_TIMEFRAME = 'H1'
F_LABEL_PERIOD = 120
F_LABEL_TIMEFRAME_SECONDS = 900

TF_ARRAY = np.array(['H1', 'H4', 'D1', 'M15', 'M5'])

tfs = TF_ARRAY[TF_ARRAY != F_LABEL_TIMEFRAME]

_mof = []

if F_SINGLE_MEDIUM:
    _mof.append('m')
else:
    _mof.append('s')

_mof.append(str(DAY_HISTORY_TO_PROCESS))

if F_VOLUME:
    _mof.append('v1')
else:
    _mof.append('v0')

_mof.append('r' + str(F_REPEAT))

if F_TIME:
    _mof.append('t1')
else:
    _mof.append('t0')


MODELS_FOLDER = 'C:/Projects/quantsmono/Python/etfc/models/' + '_'.join(_mof) + '-' + F_LABEL_TIMEFRAME + '_' + str(F_LABEL_PERIOD) + '/'

models = [tf.keras.models.load_model(MODELS_FOLDER + 'model_0'),
          tf.keras.models.load_model(MODELS_FOLDER + 'model_1'),
          tf.keras.models.load_model(MODELS_FOLDER + 'model_2'),
          tf.keras.models.load_model(MODELS_FOLDER + 'model_3'),
          tf.keras.models.load_model(MODELS_FOLDER + 'model_4'),
          tf.keras.models.load_model(MODELS_FOLDER + 'model_5'),
          tf.keras.models.load_model(MODELS_FOLDER + 'model_6'),
          tf.keras.models.load_model(MODELS_FOLDER + 'model_7'),
          tf.keras.models.load_model(MODELS_FOLDER + 'model_8'),
          tf.keras.models.load_model(MODELS_FOLDER + 'model_9'),
          tf.keras.models.load_model(MODELS_FOLDER + 'model_10'),
          tf.keras.models.load_model(MODELS_FOLDER + 'model_11'),
          tf.keras.models.load_model(MODELS_FOLDER + 'model_12'),
          tf.keras.models.load_model(MODELS_FOLDER + 'model_13')]


def self_diff(a: np.ndarray, shift=1):
    return a - np.roll(a, -shift)

def build_features_one_timeframe(raw_data):
# def build_features_one_timeframe(raw_data, outt = []):
    # raw_data: old -> new
    d = np.flipud(raw_data)
    # outt.append(str(d[:,5]))
    # d: new -> old
    ts = [datetime.fromtimestamp(x) for x in d[:,5]]
    # outt.append('c')
    tt = [t.timetuple() for t in ts]
    # outt.append('d')
    # outt.append(str(np.array(d).shape) + '0')
    a = np.array([
        d[:, 0],
        d[:, 1],
        d[:, 2],
        d[:, 3],
        np.maximum(d[:, 0], d[:, 3]),
        np.minimum(d[:, 0], d[:, 3]),
    ], dtype=float)
    # outt.append(str(a.shape) + '1')
    if F_SINGLE_MEDIUM:
        a = np.vstack((
            a,
            d[:, 3] - d[:, 0],
            d[:, 1] - d[:, 2],
            d[:, 1] - d[:, 0],
            d[:, 1] - d[:, 3],
            d[:, 3] - d[:, 2],
            d[:, 0] - d[:, 2]
        ))
        # outt.append(str(a.shape) + '2')
        a = np.vstack((
            a,
            d[:, 1] - a[4],
            d[:, 1] - a[5],
            a[4] - d[:, 2],
            a[5] - d[:, 2],
            d[:, 3] + d[:, 0],
            d[:, 1] + d[:, 2],
            d[:, 1] + d[:, 0],
            d[:, 1] + d[:, 3],
            d[:, 0] + d[:, 2],
            d[:, 3] + d[:, 2],
            d[:, 1] + a[4],
            d[:, 1] + a[5],
            a[4] + d[:, 2],
            a[5] + d[:, 2],
        ))
        # outt.append(str(a.shape) + '3')
    if F_VOLUME:
        a = np.vstack((a, d[:,4]))
    # outt.append(str(a.shape) + '4')
    f_h_single = a.shape[0]
    for i in range(F_REPEAT):
        a = np.vstack((a, self_diff(a[i*f_h_single : (i+1)*f_h_single])))
    # outt.append(str(a.shape) + '5')
    if F_TIME:
        a = np.vstack((
            a,
            self_diff(d[:, 5]),
            (np.sin(d[:, 5] * DAY) + 1) / 2,
            (np.cos(d[:, 5] * DAY) + 1) / 2,
            (np.sin(d[:, 5] * WEEK) + 1) / 2,
            (np.cos(d[:, 5] * WEEK) + 1) / 2,
            (np.sin(d[:, 5] * YEAR) + 1) / 2,
            (np.cos(d[:, 5] * YEAR) + 1) / 2,
            np.array([t.tm_yday for t in tt]) / 365,
            np.array([t.tm_mday for t in tt]) / 30,
            # np.array([calendar.monthrange(t.tm_year, t.tm_mon)[1] for t in tt]) / 30 - a[111], // TODO: Fix this shit
            np.array([t.tm_wday for t in tt]) / 6,
            np.array([t.tm_hour for t in tt]) / 23,
            np.array([t.tm_min for t in tt]) / 59,
        ))
    # outt.append(str(a.shape) + '6')

    return a


def build_image(a, w):
    return [np.interp(x, (x.min(), x.max()), (0, 1)) for x in a[:,:w]]

#     M15    H1     H4     M5     D1
# ----50-----50-----20-----20-----10


def con_predict(raw_data_m5, raw_data_m15, raw_data_h1, raw_data_h4, raw_data_d1):
    try:
        features_m5 = build_features_one_timeframe(raw_data_m5)
    except Exception as err:
        return -1, "M5 " + str(err)
    try:
        features_m15 = build_features_one_timeframe(raw_data_m15)
    except Exception as err:
        return -1, "M15 " + str(err)
    try:
        features_h1 = build_features_one_timeframe(raw_data_h1)
    except Exception as err:
        return -1, "H1 " + str(err)
    try:
        features_h4 = build_features_one_timeframe(raw_data_h4)
    except Exception as err:
        return -1, "H4 " + str(err)
    try:
        # xxx = []
        features_d1 = build_features_one_timeframe(raw_data_d1)
        # features_d1 = build_features_one_timeframe(raw_data_d1, xxx)
    except Exception as err:
        return -1, "D1 " + str(err)
        # return -1, "D1 " + '-'.join(xxx) + ' ' + str(err)

#    PREDICT RESULT -1 D1 [ 2.02000000e+03  1.74000000e+02 -8.81876976e+08  1.60004160e+09
#      1.59978240e+09  1.59969600e+09  1.59960960e+09  1.59952320e+09
#      1.59943680e+09  1.59917760e+09  1.59909120e+09  1.59900480e+09
#      1.59891840e+09  1.59883200e+09  1.59857280e+09] [Errno 22] Invalid argument
    try:
        ims = {
            'M5': build_image(features_m5, IMAGE_LENGTH_M5),
            'M15': build_image(features_m15, IMAGE_LENGTH_M15),
            'H1': build_image(features_h1, IMAGE_LENGTH_H1),
            'H4': build_image(features_h4, IMAGE_LENGTH_H4),
            'D1': build_image(features_d1, IMAGE_LENGTH_D1)
        }

        
        test_image = np.hstack((
            ims.get(F_LABEL_TIMEFRAME),
            ims.get(tfs[0]),
            ims.get(tfs[1]),
            ims.get(tfs[2]),
            ims.get(tfs[3])
        ))

    except Exception as err:
        return -2, "Error building test image " + str(err)

    try:
        b_test_im = tf.constant([test_image])
        preds = np.array([np.argmax(models[0].predict(b_test_im), axis=-1),
                          np.argmax(models[1].predict(b_test_im), axis=-1),
                          np.argmax(models[2].predict(b_test_im), axis=-1),
                          np.argmax(models[3].predict(b_test_im), axis=-1),
                          np.argmax(models[4].predict(b_test_im), axis=-1),
                          np.argmax(models[5].predict(b_test_im), axis=-1),
                          np.argmax(models[6].predict(b_test_im), axis=-1),
                          np.argmax(models[7].predict(b_test_im), axis=-1),
                          np.argmax(models[8].predict(b_test_im), axis=-1),
                          np.argmax(models[9].predict(b_test_im), axis=-1),
                          np.argmax(models[10].predict(b_test_im), axis=-1),
                          np.argmax(models[11].predict(b_test_im), axis=-1),
                          np.argmax(models[12].predict(b_test_im), axis=-1),
                          np.argmax(models[13].predict(b_test_im), axis=-1)])
    except ValueError as err:
        return -3, "ValueError preds " + str(test_image.shape) + " " + str(err)
    except Exception as err:
        return -4, "Error getting preds " + str(err)

    try:
        pred_buy = preds.flat[7:].sum()
        pred_sell = preds.flat[:7].sum()

        buy_condition = (pred_buy > pred_sell + THRESOLD_DIFF) & (pred_buy >= TARGET)

        if (buy_condition):
            return pred_buy, str(raw_data_m5[-1][5]) + " " + str(raw_data_m15[-1][5]) + " " + str(raw_data_h1[-1][5]) 
            # return 1, str(datetime.fromtimestamp(raw_data_m5[-1][5])) + " " + str(datetime.fromtimestamp(raw_data_m15[-1][5]))

        # return 0, str(datetime.fromtimestamp(raw_data_m5[-1][5])) + " " + str(datetime.fromtimestamp(raw_data_m15[-1][5]))
        return 0, str(raw_data_m5[-1][5]) + " " + str(raw_data_m15[-1][5]) + " " + str(raw_data_h1[-1][5])  + " " + str(raw_data_h4[-1][5])  + " " + str(raw_data_d1[-1][5]) 
    except Exception as err:
        return -5, "Error making decision " + str(err)

