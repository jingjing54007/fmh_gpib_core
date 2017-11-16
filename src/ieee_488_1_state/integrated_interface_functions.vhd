-- IEEE 488.1 interface functions all wired together.
--
-- Author: Frank Mori Hess fmh6jj@gmail.com
-- Copyright Frank Mori Hess 2017


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.interface_function_common.all;
use work.remote_message_decoder;
use work.interface_function_AH;
use work.interface_function_C;
use work.interface_function_DC;
use work.interface_function_DT;
use work.interface_function_LE;
use work.interface_function_PP;
use work.interface_function_RL;
use work.interface_function_SH;
use work.interface_function_SR;
use work.interface_function_TE;

entity integrated_interface_functions is
	generic(
			num_counter_bits : in integer := 8
		);
	port(
		clock : in std_logic;
		
		bus_DIO_inverted_in : in std_logic_vector(7 downto 0);
		bus_REN_inverted_in : in std_logic;
		bus_IFC_inverted_in : in std_logic;
		bus_SRQ_inverted_in : in std_logic;
		bus_EOI_inverted_in : in std_logic;
		bus_ATN_inverted_in : in std_logic;
		bus_NDAC_inverted_in : in std_logic;
		bus_NRFD_inverted_in : in std_logic;
		bus_DAV_inverted_in : in std_logic;

		ist : in std_logic;
		lon : in std_logic;
		lpe : in std_logic;
		lun : in std_logic;
		ltn : in std_logic;
		pon : in std_logic;
		rsv : in std_logic;
		rtl : in std_logic;
		tcs : in std_logic;
		ton : in std_logic;

		configured_eos_character : in std_logic_vector(7 downto 0);
		ignore_eos_bit_7 : in std_logic;
		configured_primary_address : std_logic_vector(4 downto 0);
		configured_secondary_address : in std_logic_vector(4 downto 0);
		local_parallel_poll_config : in std_logic;
		local_parallel_poll_sense : in std_logic;
		local_parallel_poll_response_line : in std_logic_vector(2 downto 0);
		first_T1_terminal_count : in std_logic_vector(num_counter_bits - 1 downto 0);
		T1_terminal_count : in std_logic_vector(num_counter_bits - 1 downto 0);
		check_for_listeners : in std_logic;
		-- host should set gpib_to_host_byte_read high for a clock when it reads gpib_to_host_byte
		gpib_to_host_byte_read : in std_logic;
		host_to_gpib_data_byte : in std_logic_vector(7 downto 0);
		host_to_gpib_data_byte_end : in std_logic;
		host_to_gpib_auto_EOI_on_EOS : in std_logic;
		host_to_gpib_data_byte_write : in std_logic;
		local_STB : in std_logic_vector(7 downto 0);
		RFD_holdoff_mode : in RFD_holdoff_enum;
		-- pulse to put acceptor handshake into rfd holdoff
		RFD_holdoff_immediately_pulse : in std_logic;
		-- pulse to release rfd holdoff
		release_RFD_holdoff_pulse : in std_logic;
		
		bus_DIO_inverted_out : out std_logic_vector(7 downto 0);
		bus_REN_inverted_out : out std_logic;
		bus_IFC_inverted_out : out std_logic;
		bus_SRQ_inverted_out : out std_logic;
		bus_EOI_inverted_out : out std_logic;
		bus_ATN_inverted_out : out std_logic;
		bus_NDAC_inverted_out : out std_logic;
		bus_NRFD_inverted_out : out std_logic;
		bus_DAV_inverted_out : out std_logic;
		acceptor_handshake_state : out AH_state;
		controller_state_p1 : out C_state_p1;
		controller_state_p2 : out C_state_p2;
		controller_state_p3 : out C_state_p3;
		controller_state_p4 : out C_state_p4;
		controller_state_p5 : out C_state_p5;
		device_clear_state : out DC_state;
		device_trigger_state : out DT_state;
		listener_state_p1 : out LE_state_p1;
		listener_state_p2 : out LE_state_p2;
		parallel_poll_state_p1 : out PP_state_p1;
		parallel_poll_state_p2 : out PP_state_p2;
		remote_local_state : out RL_state;
		service_request_state : out SR_state;
		source_handshake_state : out SH_state;
		talker_state_p1 : out TE_state_p1;
		talker_state_p2 : out TE_state_p2;
		talker_state_p3 : out TE_state_p3;
		no_listeners : out std_logic;
		gpib_to_host_byte : out std_logic_vector(7 downto 0);
		gpib_to_host_byte_eos : out std_logic;
		gpib_to_host_byte_end : out std_logic;
		-- rdy false means there is a gpib to host byte waiting to be read out
		rdy : out std_logic;
		-- host_to_gpib_data_byte_latched false means a new host to gpib byte can be written in
		host_to_gpib_data_byte_latched : out std_logic
	);
 
end integrated_interface_functions;
 
architecture integrated_interface_functions_arch of integrated_interface_functions is
	signal nba : std_logic;
	signal rdy_buffer : std_logic;
	signal internal_host_to_gpib_data_byte_latched : std_logic;
	signal internal_host_to_gpib_data_byte : std_logic_vector(7 downto 0);
	signal internal_host_to_gpib_data_byte_end : std_logic;
	signal RFD_holdoff : std_logic;
	
	signal ACG : std_logic;
	signal ATN : std_logic;
	signal DAC : std_logic;
	signal DAV : std_logic;
	signal DCL : std_logic;
	signal END_msg: std_logic;
	signal EOS: std_logic;
	signal GET : std_logic;
	signal GTL : std_logic;
	signal IDY : std_logic;
	signal IFC : std_logic;
	signal LAG : std_logic;
	signal LLO : std_logic;
	signal MLA : std_logic;
	signal MTA : std_logic;
	signal MSA : std_logic;
	signal OSA : std_logic;
	signal OTA : std_logic;
	signal PCG : std_logic;
	signal PPC : std_logic;
	signal PPE : std_logic;
	signal PPE_sense : std_logic;
	signal PPE_response_line : std_logic_vector(2 downto 0);
	signal PPD : std_logic;
	signal PPU : std_logic;
	signal REN : std_logic;
	signal RFD : std_logic;
	signal RQS : std_logic;
	signal SCG : std_logic;
	signal SDC : std_logic;
	signal SPD : std_logic;
	signal SPE : std_logic;
	signal SRQ : std_logic;
	signal TCT : std_logic;
	signal TAG : std_logic;
	signal UCG : std_logic;
	signal UNL : std_logic;
	signal UNT : std_logic;
	signal NIC : std_logic;
	signal CFE : std_logic;
	signal NUL : std_logic;
	signal local_PPR : std_logic_vector(7 downto 0);
	signal local_ATN : std_logic;
	signal local_DAC : std_logic;
	signal local_DAV : std_logic;
	signal local_END : std_logic;
	signal local_IFC : std_logic;
	signal local_REN : std_logic;
	signal local_RFD : std_logic;
	signal local_RQS : std_logic;
	signal local_SRQ : std_logic;
	signal local_IDY : std_logic;
	signal local_EOI : std_logic;
	signal talker_NUL_buffer : std_logic;
	signal controller_NUL_buffer : std_logic;
	signal local_NUL : std_logic;
	signal local_TCT : std_logic;
	
	signal acceptor_handshake_state_buffer : AH_state;
	signal controller_state_p1_buffer : C_state_p1;
	signal controller_state_p2_buffer : C_state_p2;
	signal controller_state_p3_buffer : C_state_p3;
	signal controller_state_p4_buffer : C_state_p4;
	signal controller_state_p5_buffer : C_state_p5;
	signal device_clear_state_buffer : DC_state;
	signal device_trigger_state_buffer : DT_state;
	signal listener_state_p1_buffer : LE_state_p1;
	signal listener_state_p2_buffer : LE_state_p2;
	signal parallel_poll_state_p1_buffer : PP_state_p1;
	signal parallel_poll_state_p2_buffer : PP_state_p2;
	signal remote_local_state_buffer : RL_state;
	signal source_handshake_state_buffer : SH_state;
	signal service_request_state_buffer : SR_state;
	signal talker_state_p1_buffer : TE_state_p1;
	signal talker_state_p2_buffer : TE_state_p2;
	signal talker_state_p3_buffer : TE_state_p3;
	signal bus_dio_inverted_out_buffer : std_logic_vector(7 downto 0);
	
	signal status_byte_buffer : std_logic_vector(7 downto 0);
	
	signal enable_secondary_addressing : std_logic;
	signal parallel_poll_sense : std_logic;
	signal parallel_poll_response_line : std_logic_vector(2 downto 0);

	begin
	my_decoder: entity work.remote_message_decoder 
		port map (
			bus_DIO_inverted => bus_DIO_inverted_in,
			bus_REN_inverted => bus_REN_inverted_in,
			bus_IFC_inverted => bus_IFC_inverted_in,
			bus_SRQ_inverted => bus_SRQ_inverted_in,
			bus_EOI_inverted => bus_EOI_inverted_in,
			bus_ATN_inverted => bus_ATN_inverted_in,
			bus_NDAC_inverted => bus_NDAC_inverted_in,
			bus_NRFD_inverted => bus_NRFD_inverted_in,
			bus_DAV_inverted => bus_DAV_inverted_in,
			configured_eos_character => configured_eos_character,
			ignore_eos_bit_7 => ignore_eos_bit_7,
			configured_primary_address => configured_primary_address,
			configured_secondary_address => configured_secondary_address,
			ACG => ACG,
			ATN => ATN,
			DAC => DAC,
			DAV => DAV,
			DCL => DCL,
			END_msg => END_msg,
			EOS => EOS,
			GET => GET,
			GTL => GTL,
			IDY => IDY,
			IFC => IFC,
			LAG => LAG,
			LLO => LLO,
			MLA => MLA,
			MTA => MTA,
			MSA => MSA,
			OSA => OSA,
			OTA => OTA,
			NUL => NUL,
			PCG => PCG,
			PPC => PPC,
			PPE => PPE,
			PPE_sense => PPE_sense,
			PPE_response_line => PPE_response_line,
			PPD => PPD,
			PPU => PPU,
			REN => REN,
			RFD => RFD,
			RQS => RQS,
			SCG => SCG,
			SDC => SDC,
			SPD => SPD,
			SPE => SPE,
			SRQ => SRQ,
			TCT => TCT,
			TAG => TAG,
			UCG => UCG,
			UNL => UNL,
			UNT => UNT,
			NIC => NIC,
			CFE => CFE
		);

	my_AH: entity work.interface_function_AH 
		port map (
			clock => clock,
			listener_state_p1 => listener_state_p1_buffer,
			ATN => ATN,
			DAV => DAV,
			pon => pon,
			rdy => rdy_buffer,
			tcs => tcs,
			RFD_holdoff => RFD_holdoff,
			acceptor_handshake_state => acceptor_handshake_state_buffer,
			RFD => local_RFD,
			DAC => local_DAC
		);

	my_DC: entity work.interface_function_DC 
		port map (
			clock => clock,
			acceptor_handshake_state => acceptor_handshake_state_buffer,
			listener_state_p1 => listener_state_p1_buffer,
			DCL => DCL,
			SDC => SDC,
			device_clear_state => device_clear_state_buffer
		);

	my_DT: entity work.interface_function_DT 
		port map (
			clock => clock,
			acceptor_handshake_state => acceptor_handshake_state_buffer,
			listener_state_p1 => listener_state_p1_buffer,
			GET => GET,
			device_trigger_state => device_trigger_state_buffer
		);

	my_LE: entity work.interface_function_LE 
		port map (
			clock => clock,
			acceptor_handshake_state => acceptor_handshake_state_buffer,
			controller_state_p1 => controller_state_p1_buffer,
			talker_state_p2 => talker_state_p2_buffer,
			ATN => ATN,
			IFC => IFC,
			pon => pon,
			ltn => ltn,
			lon => lon,
			lun => lun,
			UNL => UNL,
			MLA => MLA,
			MSA => MSA,
			PCG => PCG,
			MTA => MTA,
			enable_secondary_addressing => enable_secondary_addressing,
			listener_state_p1 => listener_state_p1_buffer,
			listener_state_p2 => listener_state_p2_buffer
		);

	my_PP: entity work.interface_function_PP 
		port map (
			clock => clock,
			acceptor_handshake_state => acceptor_handshake_state_buffer,
			listener_state_p1 => listener_state_p1_buffer,
			ATN => ATN,
			PPC => PPC,
			PPD => PPD,
			PPE => PPE,
			PPU => PPU,
			IDY => IDY,
			pon => pon,
			lpe => lpe,
			ist => ist,
			sense => parallel_poll_sense,
			PCG => PCG,
			local_configuration_mode => local_parallel_poll_config,
			PPR_line => parallel_poll_response_line,
			PPR => local_PPR,
			parallel_poll_state_p1 => parallel_poll_state_p1_buffer,
			parallel_poll_state_p2 => parallel_poll_state_p2_buffer
		);

	my_RL: entity work.interface_function_RL 
		port map (
			clock => clock,
			acceptor_handshake_state => acceptor_handshake_state_buffer,
			listener_state_p1 => listener_state_p1_buffer,
			listener_state_p2 => listener_state_p2_buffer,
			pon => pon,
			rtl => rtl,
			REN => REN,
			LLO => LLO,
			GTL => GTL,
			MLA => MLA,
			MSA => MSA,
			enable_secondary_addressing => enable_secondary_addressing,
			remote_local_state => remote_local_state_buffer
		);

	my_SH : entity work.interface_function_SH
		generic map (num_counter_bits => num_counter_bits)
		port map (
			clock => clock,
			talker_state_p1 => talker_state_p1_buffer,
			controller_state_p1 => controller_state_p1_buffer,
			ATN => ATN,
			DAC => DAC,
			RFD => RFD,
			nba => nba,
			pon => pon,
			first_T1_terminal_count => first_T1_terminal_count,
			T1_terminal_count => T1_terminal_count,
			check_for_listeners => check_for_listeners,
			
			source_handshake_state => source_handshake_state_buffer,
			DAV => local_DAV,
			no_listeners => no_listeners
		);

	my_SR: entity work.interface_function_SR 
		port map (
			clock => clock,
			talker_state_p1 => talker_state_p1_buffer,
			pon => pon,
			rsv => rsv,
			service_request_state => service_request_state_buffer,
			SRQ => local_SRQ
		);

	my_TE: entity work.interface_function_TE 
		port map (
			clock => clock,
			acceptor_handshake_state => acceptor_handshake_state_buffer,
			listener_state_p2 => listener_state_p2_buffer,
			service_request_state => service_request_state_buffer,
			source_handshake_state => source_handshake_state_buffer,
			ATN => ATN,
			IFC => IFC,
			pon => pon,
			ton => ton,
			MTA => MTA,
			MSA => MSA,
			OTA => OTA,
			OSA => OSA,
			MLA => MLA,
			SPE => SPE,
			SPD => SPD,
			PCG => PCG,
			enable_secondary_addressing => enable_secondary_addressing,
			host_to_gpib_data_byte_end => internal_host_to_gpib_data_byte_end,
			talker_state_p1 => talker_state_p1_buffer,
			talker_state_p2 => talker_state_p2_buffer,
			talker_state_p3 => talker_state_p3_buffer,
			END_msg => local_END,
			RQS => local_RQS,
			NUL => talker_NUL_buffer
		);
		
	my_C: entity work.interface_function_C
		port map (
			clock => clock,
			pon => pon,
			ATN => local_ATN,
			IDY => local_IDY,
			IFC => local_IFC,
			REN => local_REN,
			NUL => controller_NUL_buffer,
			TCT => local_TCT,
			controller_state_p1 => controller_state_p1_buffer,
			controller_state_p2 => controller_state_p2_buffer,
			controller_state_p3 => controller_state_p3_buffer,
			controller_state_p4 => controller_state_p4_buffer,
			controller_state_p5 => controller_state_p5_buffer
		);

	acceptor_handshake_state <= acceptor_handshake_state_buffer;
	controller_state_p1 <= controller_state_p1_buffer;
	controller_state_p2 <= controller_state_p2_buffer;
	controller_state_p3 <= controller_state_p3_buffer;
	controller_state_p4 <= controller_state_p4_buffer;
	controller_state_p5 <= controller_state_p5_buffer;
	device_clear_state <= device_clear_state_buffer;
	device_trigger_state <= device_trigger_state_buffer;
	listener_state_p1 <= listener_state_p1_buffer;
	listener_state_p2 <= listener_state_p2_buffer;
	parallel_poll_state_p1 <= parallel_poll_state_p1_buffer;
	parallel_poll_state_p2 <= parallel_poll_state_p2_buffer;
	remote_local_state <= remote_local_state_buffer;
	service_request_state <= service_request_state_buffer;
	source_handshake_state <= source_handshake_state_buffer;
	talker_state_p1 <= talker_state_p1_buffer;
	talker_state_p2 <= talker_state_p2_buffer;
	talker_state_p3 <= talker_state_p3_buffer;
	
	enable_secondary_addressing <= '1' when 
			to_X01(configured_secondary_address) /= NO_ADDRESS_CONFIGURED
		else
			'0';
	
	nba <= '1' when source_handshake_state_buffer = SGNS and
			to_bit(internal_host_to_gpib_data_byte_latched) = '1' else
		'0';
	
	host_to_gpib_data_byte_latched <= internal_host_to_gpib_data_byte_latched;

	local_NUL <= talker_NUL_buffer or controller_NUL_buffer;

	local_EOI <= local_END or local_IDY;
	
	status_byte_buffer(7) <= not local_STB(7); 
	status_byte_buffer(6) <= not local_RQS; 
	status_byte_buffer(5 downto 0) <= not local_STB(5 downto 0);

	bus_ATN_inverted_out <= not local_ATN when
		controller_state_p1_buffer /= CIDS and controller_state_p1_buffer /= CADS else 'Z';
	bus_DAV_inverted_out <= not local_DAV when
		source_handshake_state_buffer /= SIDS and source_handshake_state_buffer /= SIWS else 'Z';
	bus_EOI_inverted_out <= not (local_EOI) when
		talker_state_p1_buffer = TACS or 
		(
			controller_state_p1_buffer /= CIDS and 
			controller_state_p1_buffer /= CADS and 
			controller_state_p1_buffer /= CSBS and 
			controller_state_p1_buffer /= CSHS 
		) else 'Z';
	bus_IFC_inverted_out <= not local_IFC when
		controller_state_p5_buffer /= SIIS else 'Z';
	bus_NDAC_inverted_out <= to_X0Z(local_DAC);
	bus_NRFD_inverted_out <= to_X0Z(local_RFD);
	bus_REN_inverted_out <= not local_REN when
		controller_state_p4_buffer /= SRIS else 'Z';
	bus_SRQ_inverted_out <= to_X0Z(not local_SRQ);

	process(pon, clock)
	begin
		if pon = '1' then
			bus_DIO_inverted_out_buffer <= (others => 'Z');  
		elsif rising_edge(clock) then
		
			if (source_handshake_state_buffer = SDYS or source_handshake_state_buffer = STRS) and
				to_X01(ATN) = '0' then
				bus_DIO_inverted_out_buffer <= not internal_host_to_gpib_data_byte;
			elsif talker_state_p1_buffer = SPAS then
				bus_DIO_inverted_out_buffer <= not status_byte_buffer;
			elsif to_X01(local_TCT) = '1' then
				bus_DIO_inverted_out_buffer <= not "00001001";
			elsif parallel_poll_state_p1_buffer = PPAS then
				bus_DIO_inverted_out_buffer <= to_X0Z(not local_PPR);
			elsif (talker_state_p1_buffer = TACS or controller_state_p1_buffer = CACS) then
				if to_X01(local_NUL) = '1' then
					bus_DIO_inverted_out_buffer <= (others => '1');
				end if;
			else
				bus_DIO_inverted_out_buffer <= (others => 'Z');
			end if;
		end if;
	end process;
	bus_DIO_inverted_out <= bus_DIO_inverted_out_buffer;

	-- deal with byte read by host from gpib bus
	process(pon, clock) 
		variable prev_acceptor_handshake_state : AH_state;
	begin
		if to_bit(pon) = '1' then
			rdy_buffer <= '1';
			gpib_to_host_byte <= X"00";
			gpib_to_host_byte_end <= '0';
			gpib_to_host_byte_eos <= '0';
			RFD_holdoff <= '0';
			prev_acceptor_handshake_state := AIDS;
		elsif rising_edge(clock) then
			if prev_acceptor_handshake_state /= ACDS and 
				acceptor_handshake_state_buffer = ACDS and
				to_bit(ATN) = '0' then
				rdy_buffer <= '0';
				if RFD_holdoff_mode /= continuous_mode then
					gpib_to_host_byte <= not bus_DIO_inverted_in;
					gpib_to_host_byte_end <= END_msg;
					gpib_to_host_byte_eos <= EOS;
				end if;
				case RFD_holdoff_mode is
					when holdoff_normal =>
					when holdoff_on_all =>
						RFD_holdoff <= '1';
					when holdoff_on_end =>
						if to_X01(END_msg or EOS) = '1' then
							RFD_holdoff <= '1';
						end if;
					when continuous_mode =>
						if to_X01(END_msg or EOS) = '1' then
							RFD_holdoff <= '1';
						end if;
				end case;
			elsif acceptor_handshake_state_buffer /= ACDS and RFD_holdoff_mode = continuous_mode then
				rdy_buffer <= '1';
			elsif to_X01(gpib_to_host_byte_read) = '1' then
				rdy_buffer <= '1';
			end if;
			if to_X01(release_RFD_holdoff_pulse) = '1' then
				RFD_holdoff <= '0';
			end if;
			if to_X01(RFD_holdoff_immediately_pulse) = '1' then
				RFD_holdoff <= '1';
			end if;
			prev_acceptor_handshake_state := acceptor_handshake_state_buffer;
		end if;
	end process;

	-- deal with byte written by host to gpib bus
	process(pon, clock)
		variable prev_source_handshake_state  : SH_state;
	begin
		if to_bit(pon) = '1' then
			internal_host_to_gpib_data_byte_latched <= '0';
			internal_host_to_gpib_data_byte <= X"00";
			internal_host_to_gpib_data_byte_end <= '0';
			prev_source_handshake_state := SIDS;
		elsif rising_edge(clock) then
			if prev_source_handshake_state /= STRS and 
				source_handshake_state_buffer = STRS and
				to_bit(ATN) = '0' then
					internal_host_to_gpib_data_byte_latched <= '0';
			end if;
			if device_clear_state_buffer = DCAS then
				internal_host_to_gpib_data_byte_latched <= '0';
			elsif to_bit(host_to_gpib_data_byte_write) = '1' then
				internal_host_to_gpib_data_byte <= host_to_gpib_data_byte;
				if host_to_gpib_data_byte_end = '1' or
					(host_to_gpib_auto_EOI_on_EOS = '1' and 
					EOS_match(internal_host_to_gpib_data_byte, configured_eos_character, ignore_eos_bit_7)) then
					internal_host_to_gpib_data_byte_end <= '1';
				else
					internal_host_to_gpib_data_byte_end <= '0';
				end if;
				internal_host_to_gpib_data_byte_latched <= '1';
			end if;
			prev_source_handshake_state := source_handshake_state_buffer;
		end if;
	end process;

	-- update parallel poll sense and line
	process(pon, clock) 
	begin
		if to_bit(pon) = '1' then
			parallel_poll_sense <= '1';
			parallel_poll_response_line <= "000";
		elsif rising_edge(clock) then
			if to_bit(local_parallel_poll_config) = '1' then
				parallel_poll_sense <= local_parallel_poll_sense;
				parallel_poll_response_line <= local_parallel_poll_response_line;
			else
				if to_bit(PPE) = '1' then
					parallel_poll_sense <= PPE_sense;
					parallel_poll_response_line <= PPE_response_line;
				end if;
			end if;
		end if;
	end process;
	
	rdy <= rdy_buffer;
end integrated_interface_functions_arch;
