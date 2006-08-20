#!perl

use Module::Build;
use lib './t/lib';
Module::Build->new(
	module_name => 'Summit',
	license => 'redhotpenguin_llc',
	requires => {
		'perl' => '5.8.6',
		'Net::SMTP' => 2.29,
		'MIME::Tools' => 6.110,
	},
)->create_build_script();