{
	'includes':
	[
		'../common.gypi',
	],
	
	'targets':
	[
		{
			'target_name': 'libcurl',
			'type': 'none',
			
			'toolsets': ['host', 'target'],

			'dependencies':
			[
				'fetch.gyp:fetch',
				'libopenssl.gyp:libopenssl',
			],
			
			'direct_dependent_settings':
			{
				'target_conditions':
				[
					[
						'toolset_os == "win"',
						{
							'include_dirs':
							[
								'unpacked/curl/<(uniform_arch)-win32-$(PlatformToolset)_static_$(ConfigurationName)/include',
							],
						},
					],
					[
						'toolset_os != "win"',
						{
							'include_dirs':
							[
								'../thirdparty/libcurl/include',
							],
						},
					],
				],
			},
			
			'link_settings':
			{
				'target_conditions':
				[
					[
						'toolset_os == "mac"',
						{
							'libraries':
							[
								'$(SDKROOT)/usr/lib/libcurl.dylib',
							],
						},
					],
					[
						'toolset_os == "linux"',
						{
							'library_dirs':
							[
								'lib/linux/>(toolset_arch)',
							],

							'libraries':
							[
								'-lcurl',
								'-lrt',
							],
						},
					],
				],
			},

			# On Windows, link_settings inside target_conditions is rejected by
			# the GYP MSVS generator ("not allowed in the Debug configuration").
			# Use all_dependent_settings instead so that the library dir and
			# import lib name propagate correctly to every executable that links
			# (directly or transitively) against libcurl — including server.vcxproj.
			# ws2_32, wldap32, and crypt32 are Windows system libs required by the
			# libcurl_a static library.
			'all_dependent_settings':
			{
				'target_conditions':
				[
					[
						'toolset_os == "win"',
						{
							'link_settings':
							{
								'library_dirs':
								[
									'unpacked/curl/<(uniform_arch)-win32-$(PlatformToolset)_static_$(ConfigurationName)/lib',
								],

								'libraries':
								[
									'-llibcurl_a',
									'-lws2_32',
									'-lwldap32',
									'-lcrypt32',
								],
							},
						},
					],
				],
			},
		},
	],
}
