'use strict';
'require view';
'require form';
'require uci';
'require ui';
'require rpc';

return view.extend({
	title: _('Link Monitor - Configuration'),

	load: function() {
		return uci.load('linkmonitor');
	},

	render: function() {
		var m, s, o;

		m = new form.Map('linkmonitor', _('Link Monitor Configuration'),
			_('Configure network links to monitor and alert rules. The daemon will periodically check each link and trigger alerts on state changes.'));

		/* ===== Global Settings ===== */
		s = m.section(form.NamedSection, 'global', 'global', _('Global Settings'));
		s.anonymous = false;

		o = s.option(form.Flag, 'enabled', _('Enable Monitoring'),
			_('Enable or disable the link monitoring daemon.'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Value, 'interval', _('Default Check Interval (seconds)'),
			_('Default interval between checks. Individual links can override this.'));
		o.datatype = 'uinteger';
		o.default = '30';
		o.placeholder = '30';

		o = s.option(form.Value, 'history_size', _('History Size'),
			_('Maximum number of events to keep in the history log.'));
		o.datatype = 'uinteger';
		o.default = '200';
		o.placeholder = '200';

		/* ===== Monitored Links ===== */
		s = m.section(form.TableSection, 'link', _('Monitored Links'),
			_('Define the network hosts and services to monitor.'));
		s.anonymous = true;
		s.addremove = true;
		s.sortable = true;
		s.addbtntitle = _('Add Link');

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = '1';
		o.editable = true;

		o = s.option(form.Value, 'name', _('Name'),
			_('Descriptive name for this link.'));
		o.rmempty = false;
		o.placeholder = _('e.g. WAN Gateway');

		o = s.option(form.Value, 'host', _('Host / URL'),
			_('IP address, hostname, or full URL to check.'));
		o.rmempty = false;
		o.placeholder = _('e.g. 8.8.8.8 or https://example.com');

		o = s.option(form.ListValue, 'method', _('Method'),
			_('Check method to use.'));
		o.value('ping', _('Ping (ICMP)'));
		o.value('http', _('HTTP/HTTPS'));
		o.value('dns', _('DNS Lookup'));
		o.default = 'ping';

		o = s.option(form.Value, 'interval', _('Interval (s)'),
			_('Check interval in seconds. Leave empty to use global default.'));
		o.datatype = 'uinteger';
		o.placeholder = _('global');
		o.optional = true;

		o = s.option(form.Value, 'timeout', _('Timeout (s)'),
			_('Seconds to wait before considering the check failed.'));
		o.datatype = 'uinteger';
		o.default = '5';
		o.placeholder = '5';

		o = s.option(form.Value, 'retries', _('Retries'),
			_('Number of ping attempts (ping method only).'));
		o.datatype = 'uinteger';
		o.default = '3';
		o.placeholder = '3';
		o.depends('method', 'ping');

		/* ===== Alert Rules ===== */
		s = m.section(form.TableSection, 'alert', _('Alert Rules'),
			_('Configure actions to trigger when a link state changes.'));
		s.anonymous = true;
		s.addremove = true;
		s.sortable = true;
		s.addbtntitle = _('Add Alert');

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.default = '1';
		o.editable = true;

		o = s.option(form.Value, 'name', _('Name'),
			_('Descriptive name for this alert rule.'));
		o.rmempty = false;
		o.placeholder = _('e.g. Email Admin');

		o = s.option(form.ListValue, 'type', _('Type'),
			_('Alert delivery method.'));
		o.value('syslog', _('Syslog'));
		o.value('email', _('Email'));
		o.value('script', _('Custom Script'));
		o.value('webhook', _('Webhook (HTTP POST)'));
		o.default = 'syslog';

		o = s.option(form.ListValue, 'trigger', _('Trigger On'),
			_('When to fire this alert.'));
		o.value('both', _('Both (Up & Down)'));
		o.value('down', _('Link Down Only'));
		o.value('up', _('Link Recovery Only'));
		o.default = 'both';

		/* Email-specific options */
		o = s.option(form.Value, 'recipient', _('Recipient Email'),
			_('Email address to send alerts to. Requires sendmail/msmtp.'));
		o.placeholder = 'admin@example.com';
		o.depends('type', 'email');
		o.optional = true;

		o = s.option(form.Value, 'subject_prefix', _('Subject Prefix'));
		o.placeholder = '[LinkMonitor]';
		o.depends('type', 'email');
		o.optional = true;

		/* Script-specific options */
		o = s.option(form.Value, 'path', _('Script Path'),
			_('Full path to the script. Called with args: name host state latency.'));
		o.placeholder = '/usr/bin/my-alert.sh';
		o.depends('type', 'script');
		o.optional = true;

		/* Webhook-specific options */
		o = s.option(form.Value, 'url', _('Webhook URL'),
			_('URL to POST a JSON payload to on state change.'));
		o.placeholder = 'https://hooks.example.com/alert';
		o.depends('type', 'webhook');
		o.optional = true;

		return m.render();
	}
});
