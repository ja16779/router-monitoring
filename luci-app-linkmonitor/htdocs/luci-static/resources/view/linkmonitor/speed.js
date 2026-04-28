'use strict';
'require view';
'require dom';
'require rpc';
'require ui';

var callGetSpeedHistory = rpc.declare({
	object: 'linkmonitor', method: 'get_speed_history', params: ['limit'], expect: { speed_history: [] }
});
var callClearSpeedHistory = rpc.declare({
	object: 'linkmonitor', method: 'clear_speed_history', expect: {}
});

function speedBarInline(mbps, maxMbps, color) {
	maxMbps = maxMbps || 100;
	if (maxMbps < 1) maxMbps = 1;
	var pct = Math.min((mbps / maxMbps) * 100, 100);
	return E('div', { style: 'display:flex;align-items:center;gap:6px;min-width:150px' }, [
		E('div', { style: 'flex:1;height:10px;background:#e0e0e0;border-radius:5px;overflow:hidden;min-width:80px' }, [
			E('div', { style: 'height:100%;width:'+pct+'%;background:'+(color||'#2196f3')+';border-radius:5px;transition:width .3s' })
		]),
		E('span', { style: 'font-size:12px;min-width:70px;font-weight:bold' }, mbps.toFixed(2))
	]);
}

return view.extend({
	title: _('Speed History'),

	load: function() {
		return callGetSpeedHistory(500);
	},

	render: function(data) {
		var history = (data || []).slice().reverse();
		var self = this;

		/* Gather unique interface names for filter */
		var ifaces = {};
		for (var i = 0; i < history.length; i++) {
			var ifn = history[i].iface || history[i].ifname || 'unknown';
			ifaces[ifn] = true;
		}
		var ifaceList = Object.keys(ifaces).sort();

		/* Find max values for bar scaling */
		var maxDl = 1, maxUl = 1;
		for (var i = 0; i < history.length; i++) {
			if ((history[i].download || 0) > maxDl) maxDl = history[i].download;
			if ((history[i].upload || 0) > maxUl) maxUl = history[i].upload;
		}
		var maxSpeed = Math.max(maxDl, maxUl, 1);

		/* Filter dropdown */
		var filterSelect = E('select', { style: 'margin-left:16px;padding:4px 8px;border:1px solid #ccc;border-radius:4px', change: function(ev) {
			var val = ev.target.value;
			var rows = document.querySelectorAll('tr[data-iface]');
			for (var r = 0; r < rows.length; r++) {
				if (val === 'all' || rows[r].getAttribute('data-iface') === val) {
					rows[r].style.display = '';
				} else {
					rows[r].style.display = 'none';
				}
			}
		}}, [
			E('option', { value: 'all' }, _('All Interfaces'))
		].concat(ifaceList.map(function(n) {
			return E('option', { value: n }, n);
		})));

		/* Build rows */
		var rows = [];
		for (var j = 0; j < history.length; j++) {
			var ev = history[j];
			var ifaceName = ev.iface || ev.ifname || 'unknown';
			rows.push(E('tr', { 'data-iface': ifaceName }, [
				E('td', { style: 'padding:6px 12px;white-space:nowrap' }, ev.time || '-'),
				E('td', { style: 'padding:6px 12px' }, [
					E('span', { style: 'font-weight:bold' }, ifaceName),
					ev.ifname && ev.iface ? E('span', { style: 'margin-left:4px;padding:1px 6px;background:#e3f2fd;border-radius:4px;font-size:11px;color:#1565c0' }, ev.ifname) : ''
				]),
				E('td', { style: 'padding:6px 12px' }, speedBarInline(parseFloat(ev.download)||0, maxSpeed, '#2196f3')),
				E('td', { style: 'padding:6px 12px' }, speedBarInline(parseFloat(ev.upload)||0, maxSpeed, '#ff9800')),
				E('td', { style: 'padding:6px 12px' }, (parseFloat(ev.latency)||0).toFixed(1) + ' ms')
			]));
		}

		return E('div', {}, [
			E('h2', {}, _('Link Monitor - Speed History')),
			E('div', { style: 'display:flex;align-items:center;justify-content:space-between;margin-bottom:16px' }, [
				E('div', { style: 'display:flex;align-items:center' }, [
					E('span', { style: 'font-weight:bold' }, _('Filter: ')),
					filterSelect
				]),
				E('div', { style: 'display:flex;gap:8px' }, [
					E('button', { 'class': 'cbi-button cbi-button-negative', click: function() {
						ui.showModal(_('Clear Speed History'), [
							E('p', {}, _('Clear all speed test history data?')),
							E('div', { 'class': 'right' }, [
								E('button', { 'class': 'cbi-button', click: ui.hideModal }, _('Cancel')), ' ',
								E('button', { 'class': 'cbi-button cbi-button-negative', click: function() {
									ui.hideModal();
									callClearSpeedHistory().then(function() { window.location.reload(); });
								}}, _('Clear'))
							])
						]);
					}}, _('Clear Speed History'))
				])
			]),
			/* Summary stats */
			ifaceList.length > 0 ? E('div', { style: 'display:flex;gap:16px;flex-wrap:wrap;margin-bottom:16px' }, ifaceList.map(function(iface) {
				/* Find latest entry for this interface */
				var latest = null;
				for (var si = 0; si < history.length; si++) {
					if ((history[si].iface || history[si].ifname) === iface) { latest = history[si]; break; }
				}
				if (!latest) return '';
				return E('div', { style: 'border:1px solid #ddd;border-radius:8px;padding:12px 16px;background:#fff;min-width:200px' }, [
					E('div', { style: 'font-weight:bold;margin-bottom:8px;font-size:14px' }, iface),
					E('div', { style: 'display:flex;gap:16px;font-size:13px' }, [
						E('div', {}, [
							E('span', { style: 'color:#999' }, 'DL: '),
							E('span', { style: 'color:#2196f3;font-weight:bold' }, (parseFloat(latest.download)||0).toFixed(2) + ' Mbps')
						]),
						E('div', {}, [
							E('span', { style: 'color:#999' }, 'UL: '),
							E('span', { style: 'color:#ff9800;font-weight:bold' }, (parseFloat(latest.upload)||0).toFixed(2) + ' Mbps')
						]),
						E('div', {}, [
							E('span', { style: 'color:#999' }, 'Lat: '),
							E('span', {}, (parseFloat(latest.latency)||0).toFixed(1) + ' ms')
						])
					])
				]);
			})) : '',
			/* Table */
			E('div', { style: 'overflow-x:auto' },
				E('table', { 'class': 'table', style: 'width:100%;border-collapse:collapse' }, [
					E('thead', {}, [E('tr', { style: 'background:#f5f5f5' }, [
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Time')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Interface')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Download (Mbps)')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Upload (Mbps)')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Latency'))
					])]),
					E('tbody', {}, rows.length ? rows : [E('tr', {}, [E('td', { colspan: '5', style: 'padding:16px;text-align:center;color:#999' }, _('No speed test data yet. Enable speed tests in Configuration and wait for the first test, or run a manual test from the Overview tab.'))])])
				])
			)
		]);
	},

	handleSaveApply: null, handleSave: null, handleReset: null
});
