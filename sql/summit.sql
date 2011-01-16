--
-- PostgreSQL database dump
--

SET client_encoding = 'SQL_ASCII';
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'Standard public schema';


--
-- Name: plperl; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: 
--

CREATE PROCEDURAL LANGUAGE plperl;


--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: 
--

CREATE PROCEDURAL LANGUAGE plpgsql;


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: account; Type: TABLE; Schema: public; Owner: summit; Tablespace: 
--

CREATE TABLE account (
    account_id serial NOT NULL,
    basecamp_login character varying(64),
    basecamp_pass character varying(64),
    sender character varying(64),
    recipient character varying(64),
    active boolean,
    basecamp_url character varying(64),
    cts timestamp with time zone DEFAULT now()
);
 alter table account add primary key (account_id);

ALTER TABLE public.account OWNER TO summit;

CREATE TABLE transaction (transaction_id SERIAL NOT NULL PRIMARY KEY,
    account_id INTEGER NOT NULL,
    code INTEGER NOT NULL,
    cts timestamp with time zone DEFAULT now()
);
ALTER TABLE transaction ADD CONSTRAINT accountfk FOREIGN KEY (account_id)
REFERENCES account (account_id) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE public.transaction OWNER TO summit;
--
-- Name: account_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: summit
--

SELECT pg_catalog.setval(pg_catalog.pg_get_serial_sequence('account', 'account_id'), 38, true);


--
-- Data for Name: account; Type: TABLE DATA; Schema: public; Owner: summit
--


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: account; Type: ACL; Schema: public; Owner: summit
--

REVOKE ALL ON TABLE account FROM PUBLIC;
REVOKE ALL ON TABLE account FROM summit;
GRANT ALL ON TABLE account TO summit;


--
-- PostgreSQL database dump complete
--

