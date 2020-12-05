

if ('train_images' not in globals() or
    'train_raw' not in globals() or
        'train_labels' not in globals()):
    dict_data = load('train_data.npz')
    train_images = dict_data['images']
    train_raw = dict_data['raw']
    train_labels = dict_data['labels']


if ('test_images' not in globals() or
    'test_raw' not in globals() or
        'test_labels' not in globals()):
    dict_data = load('test_data.npz')
    test_images = dict_data['images']
    test_raw = dict_data['raw']
    test_labels = dict_data['labels']


df = pd.DataFrame(data={'time': train_raw[0], 'open': train_raw[1], 'high': train_raw[2], 'low': train_raw[3],
                        'close': train_raw[4], 'label0': train_labels[0]+train_labels[0]+train_labels[0]+train_labels[0]+train_labels[0]})
# df = df[::-1].reset_index()


p = df[:400]
p['Time'] = pd.to_datetime(p['time'], unit='s')
p = p.set_index('Time')


# p = df
apds = [
    mpf.make_addplot(p['label0'], type='scatter',
                     markersize=20, color='green', secondary_y=True),
    # mpf.make_addplot(p['label_up'], type='scatter', markersize=10, color='green', secondary_y=True),
    # mpf.make_addplot(p['label_down'], type='scatter', markersize=10, color='orange', secondary_y=True),
    # mpf.make_addplot(p['p_increase'], type='scatter', markersize=20, color='lime', marker='x', secondary_y=True),
    # mpf.make_addplot(p['p_decrease'], type='scatter', markersize=20, color='red', marker='x', secondary_y=True),
    # mpf.make_addplot(p['sell'], type='scatter',markersize=50, marker='v', color='orange'),
    # mpf.make_addplot(p['buy'], type='scatter', markersize=50, marker='^', color='lime'),
    # mpf.make_addplot(p['buy_tp'], type='scatter', markersize=50, marker='x', color='green'),
    # mpf.make_addplot(p['buy_sl'], type='scatter', markersize=50, marker='x', color='red'),
    # mpf.make_addplot(p['sell_tp'], type='scatter', markersize=50, marker='x', color='green'),
    # mpf.make_addplot(p['sell_sl'], type='scatter', markersize=50, marker='x', color='red'),
]

fig, axes = mpf.plot(p, addplot=apds, figratio=(24, 10), type='candle', style='nightclouds', volume=False,
                     datetime_format='%Y-%m-%d %H:%M', xrotation=90, tight_layout=True, returnfig=True)
axes[0].locator_params(nbins=10, axis='x')
plt.show()
