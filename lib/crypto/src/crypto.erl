%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 1999-2018. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%%

%% Purpose : Main Crypto API module.

-module(crypto).

-export([start/0, stop/0, info_lib/0, info_fips/0, supports/0, enable_fips_mode/1,
         version/0, bytes_to_integer/1]).
-export([hash/2, hash_init/1, hash_update/2, hash_final/1]).
-export([sign/4, sign/5, verify/5, verify/6]).
-export([generate_key/2, generate_key/3, compute_key/4]).
-export([hmac/3, hmac/4, hmac_init/2, hmac_update/2, hmac_final/1, hmac_final_n/2]).
-export([cmac/3, cmac/4]).
-export([poly1305/2]).
-export([exor/2, strong_rand_bytes/1, mod_pow/3]).
-export([rand_seed/0, rand_seed_alg/1]).
-export([rand_seed_s/0, rand_seed_alg_s/1]).
-export([rand_plugin_next/1]).
-export([rand_plugin_uniform/1]).
-export([rand_plugin_uniform/2]).
-export([rand_cache_plugin_next/1]).
-export([rand_uniform/2]).
-export([block_encrypt/3, block_decrypt/3, block_encrypt/4, block_decrypt/4]).
-export([next_iv/2, next_iv/3]).
-export([stream_init/2, stream_init/3, stream_encrypt/2, stream_decrypt/2]).
-export([public_encrypt/4, private_decrypt/4]).
-export([private_encrypt/4, public_decrypt/4]).
-export([privkey_to_pubkey/2]).
-export([ec_curve/1, ec_curves/0]).
-export([rand_seed/1]).
%% Engine
-export([
         engine_get_all_methods/0,
         engine_load/3,
         engine_load/4,
         engine_unload/1,
         engine_by_id/1,
         engine_list/0,
         engine_ctrl_cmd_string/3,
         engine_ctrl_cmd_string/4,
         engine_add/1,
         engine_remove/1,
         engine_get_id/1,
         engine_get_name/1,
         ensure_engine_loaded/2,
         ensure_engine_loaded/3,
         ensure_engine_unloaded/1,
         ensure_engine_unloaded/2
        ]).

-export_type([ %% A minimum exported: only what public_key needs.
               dh_private/0,
               dh_public/0,
               dss_digest_type/0,
               ec_named_curve/0,
               ecdsa_digest_type/0,
               pk_encrypt_decrypt_opts/0,
               pk_sign_verify_opts/0,
               rsa_digest_type/0,
               sha1/0,
               sha2/0
             ]).

-export_type([engine_ref/0,
              key_id/0,
              password/0
             ]).

%%% Opaque types must be exported :(
-export_type([
              stream_state/0,
              hmac_state/0,
              hash_state/0
             ]).
   
%% Private. For tests.
-export([packed_openssl_version/4, engine_methods_convert_to_bitmask/2, get_test_engine/0]).

-deprecated({rand_uniform, 2, next_major_release}).

%% This should correspond to the similar macro in crypto.c
-define(MAX_BYTES_TO_NIF, 20000). %%  Current value is: erlang:system_info(context_reductions) * 10

%% Used by strong_rand_float/0
-define(HALF_DBL_EPSILON, 1.1102230246251565e-16). % math:pow(2, -53)


%%% ===== BEGIN NEW TYPING ====

%%% Basic
-type key_integer() :: integer() | binary(). % Always binary() when used as return value

%%% Keys
-type rsa_public() :: [key_integer()] . % [E, N]
-type rsa_private() :: [key_integer()] . % [E, N, D] | [E, N, D, P1, P2, E1, E2, C]
-type rsa_params() :: {ModulusSizeInBits::integer(), PublicExponent::key_integer()} .

-type dss_public() :: [key_integer()] . % [P, Q, G, Y] 
-type dss_private() :: [key_integer()] . % [P, Q, G, X]

-type ecdsa_public()  :: key_integer() .
-type ecdsa_private() :: key_integer() .
-type ecdsa_params()  :: ec_named_curve() | edwards_curve() | ec_explicit_curve() .

-type srp_public() :: key_integer() .
-type srp_private() :: key_integer() .
-type srp_gen_params()  :: {user,srp_user_gen_params()}  | {host,srp_host_gen_params()}.
-type srp_comp_params() :: {user,srp_user_comp_params()} | {host,srp_host_comp_params()}.
-type srp_user_gen_params() :: list(binary() | atom() | list()) .
-type srp_host_gen_params() :: list(binary() | atom() | list()) .
-type srp_user_comp_params() :: list(binary() | atom()) .
-type srp_host_comp_params() :: list(binary() | atom()) .

-type dh_public() :: key_integer() .
-type dh_private() :: key_integer() .
-type dh_params() :: [key_integer()] . % [P, G] | [P, G, PrivateKeyBitLength]

-type ecdh_public()  :: key_integer() .
-type ecdh_private() :: key_integer() .
-type ecdh_params()  :: ec_named_curve() | edwards_curve() | ec_explicit_curve() .


%%% Curves

-type ec_explicit_curve() :: {Field :: ec_field(),
                              Curve :: ec_curve(),
                              BasePoint :: binary(),
                              Order :: binary(),
                              CoFactor :: none | % FIXME: Really?
                                          binary()
                             } .

-type ec_curve() :: {A :: binary(),
                     B :: binary(),
                     Seed :: none | binary()
                    } .

-type ec_field() ::  ec_prime_field() | ec_characteristic_two_field() .

-type ec_prime_field()              :: {prime_field, Prime :: integer()} .
-type ec_characteristic_two_field() :: {characteristic_two_field, M :: integer(), Basis :: ec_basis()} .

-type ec_basis() :: {tpbasis, K :: non_neg_integer()}
                  | {ppbasis, K1 :: non_neg_integer(), K2 :: non_neg_integer(), K3 :: non_neg_integer()}
                  |  onbasis .

-type ec_named_curve() :: brainpoolP160r1
                        | brainpoolP160t1
                        | brainpoolP192r1
                        | brainpoolP192t1
                        | brainpoolP224r1
                        | brainpoolP224t1
                        | brainpoolP256r1
                        | brainpoolP256t1
                        | brainpoolP320r1
                        | brainpoolP320t1
                        | brainpoolP384r1
                        | brainpoolP384t1
                        | brainpoolP512r1
                        | brainpoolP512t1
                        | c2pnb163v1
                        | c2pnb163v2
                        | c2pnb163v3
                        | c2pnb176v1
                        | c2pnb208w1
                        | c2pnb272w1
                        | c2pnb304w1
                        | c2pnb368w1
                        | c2tnb191v1
                        | c2tnb191v2
                        | c2tnb191v3
                        | c2tnb239v1
                        | c2tnb239v2
                        | c2tnb239v3
                        | c2tnb359v1
                        | c2tnb431r1
                        | ipsec3
                        | ipsec4
                        | prime192v1
                        | prime192v2
                        | prime192v3
                        | prime239v1
                        | prime239v2
                        | prime239v3
                        | prime256v1
                        | secp112r1
                        | secp112r2
                        | secp128r1
                        | secp128r2
                        | secp160k1
                        | secp160r1
                        | secp160r2
                        | secp192k1
                        | secp192r1
                        | secp224k1
                        | secp224r1
                        | secp256k1
                        | secp256r1
                        | secp384r1
                        | secp521r1
                        | sect113r1
                        | sect113r2
                        | sect131r1
                        | sect131r2
                        | sect163k1
                        | sect163r1
                        | sect163r2
                        | sect193r1
                        | sect193r2
                        | sect233k1
                        | sect233r1
                        | sect239k1
                        | sect283k1
                        | sect283r1
                        | sect409k1
                        | sect409r1
                        | sect571k1
                        | sect571r1
                        | wtls1
                        | wtls10
                        | wtls11
                        | wtls12
                        | wtls3
                        | wtls4
                        | wtls5
                        | wtls6
                        | wtls7
                        | wtls8
                        | wtls9
                          .

-type edwards_curve() :: x25519
                       | x448 .

%%% 
-type block_cipher_with_iv() :: cbc_cipher()
                              | cfb_cipher()
                              | aes_cbc128
                              | aes_cbc256
                              | aes_ige256
                              | blowfish_ofb64
                              | des3_cbf % cfb misspelled
                              | des_ede3
                              | rc2_cbc .

-type cbc_cipher()  :: des_cbc | des3_cbc | aes_cbc | blowfish_cbc .
-type aead_cipher() :: aes_gcm | chacha20_poly1305 .
-type cfb_cipher()  :: aes_cfb128 | aes_cfb8 | blowfish_cfb64 | des3_cfb | des_cfb .

-type block_cipher_without_iv() :: ecb_cipher() .
-type ecb_cipher()  :: des_ecb | blowfish_ecb | aes_ecb .

-type key() :: iodata().
-type des3_key() :: [key()].

%%%
-type rsa_digest_type()   :: sha1() | sha2() | md5 | ripemd160 .
-type dss_digest_type()   :: sha1() | sha2() .
-type ecdsa_digest_type() :: sha1() | sha2() .

-type sha1() :: sha .
-type sha2() :: sha224 | sha256 | sha384 | sha512 .
-type sha3() :: sha3_224 | sha3_256 | sha3_384 | sha3_512 .

-type compatibility_only_hash() :: md5 | md4 .

-type crypto_integer() :: binary() | integer().

-compile(no_native).
-on_load(on_load/0).
-define(CRYPTO_NIF_VSN,302).

-define(nif_stub,nif_stub_error(?LINE)).
nif_stub_error(Line) ->
    erlang:nif_error({nif_not_loaded,module,?MODULE,line,Line}).

%%--------------------------------------------------------------------
%%% API
%%--------------------------------------------------------------------
%% Crypto app version history:
%% (no version): Driver implementation
%% 2.0         : NIF implementation, requires OTP R14

%% When generating documentation from crypto.erl, the macro ?CRYPTO_VSN is not defined.
%% That causes the doc generation to stop...
-ifndef(CRYPTO_VSN).
-define(CRYPTO_VSN, "??").
-endif.
version() -> ?CRYPTO_VSN.

-spec start() -> ok | {error, Reason::term()}.
start() ->
    application:start(crypto).

-spec stop() -> ok | {error, Reason::term()}.
stop() ->
    application:stop(crypto).

-spec supports() -> [Support]
                        when Support :: {hashs,   Hashs}
                                      | {ciphers, Ciphers}
                                      | {public_keys, PKs}
                                      | {macs,    Macs}
                                      | {curves,  Curves},
                             Hashs :: [sha1() | sha2() | sha3() | ripemd160 | compatibility_only_hash()],
                             Ciphers :: [stream_cipher()
                                         | block_cipher_with_iv() | block_cipher_without_iv()
                                         | aead_cipher()
                                        ], 
                             PKs :: [rsa | dss | ecdsa | dh | ecdh | ec_gf2m],
                             Macs :: [hmac | cmac | poly1305],
                             Curves :: [ec_named_curve() | edwards_curve()].
supports()->
    {Hashs, PubKeys, Ciphers, Macs, Curves} = algorithms(),
    [{hashs, Hashs},
     {ciphers, Ciphers},
     {public_keys, PubKeys},
     {macs, Macs},
     {curves, Curves}
    ].

-spec info_lib() -> [{Name,VerNum,VerStr}] when Name :: binary(),
                                                VerNum :: integer(),
                                                VerStr :: binary() .
info_lib() -> ?nif_stub.

-spec info_fips() -> not_supported | not_enabled | enabled.

info_fips() -> ?nif_stub.

-spec enable_fips_mode(Enable) -> Result when Enable :: boolean(),
                                              Result :: boolean().
enable_fips_mode(_) -> ?nif_stub.

%%%================================================================
%%%
%%% Hashing
%%%
%%%================================================================

-define(HASH_HASH_ALGORITHM, sha1() | sha2() | sha3() | ripemd160 | compatibility_only_hash() ).

-spec hash(Type, Data) -> Digest when Type :: ?HASH_HASH_ALGORITHM,
                                      Data :: iodata(),
                                      Digest :: binary().
hash(Type, Data) ->
    Data1 = iolist_to_binary(Data),
    MaxBytes = max_bytes(),
    hash(Type, Data1, erlang:byte_size(Data1), MaxBytes).

-opaque hash_state() :: reference().

-spec hash_init(Type) -> State when Type :: ?HASH_HASH_ALGORITHM,
                                    State :: hash_state().
hash_init(Type) -> 
    notsup_to_error(hash_init_nif(Type)).

-spec hash_update(State, Data) -> NewState when State :: hash_state(),
                                                NewState :: hash_state(),
                                                Data :: iodata() .
hash_update(Context, Data) ->
    Data1 = iolist_to_binary(Data),
    MaxBytes = max_bytes(),
    hash_update(Context, Data1, erlang:byte_size(Data1), MaxBytes).

-spec hash_final(State) -> Digest when  State :: hash_state(),
                                        Digest :: binary().
hash_final(Context) ->
    notsup_to_error(hash_final_nif(Context)).

%%%================================================================
%%%
%%% MACs (Message Authentication Codes)
%%% 
%%%================================================================

%%%---- HMAC

-define(HMAC_HASH_ALGORITHM,  sha1() | sha2() | sha3() | compatibility_only_hash()).

%%%---- hmac/3,4 

-spec hmac(Type, Key, Data) -> 
                  Mac when Type :: ?HMAC_HASH_ALGORITHM,
                           Key :: iodata(),
                           Data :: iodata(),
                           Mac :: binary() .
hmac(Type, Key, Data) ->
    Data1 = iolist_to_binary(Data),
    hmac(Type, Key, Data1, undefined, erlang:byte_size(Data1), max_bytes()).

-spec hmac(Type, Key, Data, MacLength) -> 
                  Mac when Type :: ?HMAC_HASH_ALGORITHM,
                           Key :: iodata(),
                           Data :: iodata(),
                           MacLength :: integer(),
                           Mac :: binary() .

hmac(Type, Key, Data, MacLength) ->
    Data1 = iolist_to_binary(Data),
    hmac(Type, Key, Data1, MacLength, erlang:byte_size(Data1), max_bytes()).

%%%---- hmac_init, hamc_update, hmac_final

-opaque hmac_state() :: binary().

-spec hmac_init(Type, Key) ->
                       State when Type :: ?HMAC_HASH_ALGORITHM,
                                  Key :: iodata(),
                                  State :: hmac_state() .
hmac_init(Type, Key) ->
    notsup_to_error(hmac_init_nif(Type, Key)).

%%%---- hmac_update

-spec hmac_update(State, Data) -> NewState when Data :: iodata(),
                                                State :: hmac_state(),
                                                NewState :: hmac_state().
hmac_update(State, Data0) ->
    Data = iolist_to_binary(Data0),
    hmac_update(State, Data, erlang:byte_size(Data), max_bytes()).

%%%---- hmac_final

-spec hmac_final(State) -> Mac when State :: hmac_state(),
                                    Mac :: binary().
hmac_final(Context) ->
    notsup_to_error(hmac_final_nif(Context)).

-spec hmac_final_n(State, HashLen) -> Mac when State :: hmac_state(),
                                               HashLen :: integer(),
                                               Mac :: binary().
hmac_final_n(Context, HashLen) ->
    notsup_to_error(hmac_final_nif(Context, HashLen)).

%%%---- CMAC

-define(CMAC_CIPHER_ALGORITHM, cbc_cipher() | cfb_cipher() | blowfish_cbc | des_ede3 | rc2_cbc  ).

-spec cmac(Type, Key, Data) ->
                  Mac when Type :: ?CMAC_CIPHER_ALGORITHM,
                           Key :: iodata(),
                           Data :: iodata(),
                           Mac :: binary().
cmac(Type, Key, Data) ->
    notsup_to_error(cmac_nif(Type, Key, Data)).

-spec cmac(Type, Key, Data, MacLength) ->
                  Mac when Type :: ?CMAC_CIPHER_ALGORITHM,
                           Key :: iodata(),
                           Data :: iodata(),
                           MacLength :: integer(), 
                           Mac :: binary().
cmac(Type, Key, Data, MacLength) ->
    erlang:binary_part(cmac(Type, Key, Data), 0, MacLength).

%%%---- POLY1305

-spec poly1305(iodata(), iodata()) -> Mac when Mac ::  binary().

poly1305(Key, Data) ->
    poly1305_nif(Key, Data).

%%%================================================================
%%%
%%% Encrypt/decrypt
%%%
%%%================================================================

%%%---- Block ciphers

-spec block_encrypt(Type::block_cipher_with_iv(), Key::key()|des3_key(), Ivec::binary(), PlainText::iodata()) -> binary();
                   (Type::aead_cipher(),  Key::iodata(), Ivec::binary(), {AAD::binary(), PlainText::iodata()}) ->
                           {binary(), binary()};
                   (aes_gcm, Key::iodata(), Ivec::binary(), {AAD::binary(), PlainText::iodata(), TagLength::1..16}) ->
                           {binary(), binary()}.

block_encrypt(Type, Key, Ivec, PlainText) when Type =:= des_cbc;
                                          Type =:= des_cfb;
                                          Type =:= blowfish_cbc;
                                          Type =:= blowfish_cfb64;
                                          Type =:= blowfish_ofb64;
                                          Type =:= aes_cbc128;
                                          Type =:= aes_cfb8;
                                          Type =:= aes_cfb128;
                                          Type =:= aes_cbc256;
					  Type =:= aes_cbc;
                                          Type =:= rc2_cbc ->
    block_crypt_nif(Type, Key, Ivec, PlainText, true);
block_encrypt(Type, Key0, Ivec, PlainText) when Type =:= des3_cbc;
                                           Type =:= des_ede3 ->
    Key = check_des3_key(Key0),
    block_crypt_nif(des_ede3_cbc, Key, Ivec, PlainText, true);
block_encrypt(des3_cbf, Key0, Ivec, PlainText) -> % cfb misspelled
    Key = check_des3_key(Key0),
    block_crypt_nif(des_ede3_cbf, Key, Ivec, PlainText, true);
block_encrypt(des3_cfb, Key0, Ivec, PlainText) ->
    Key = check_des3_key(Key0),
    block_crypt_nif(des_ede3_cfb, Key, Ivec, PlainText, true);
block_encrypt(aes_ige256, Key, Ivec, PlainText) ->
    notsup_to_error(aes_ige_crypt_nif(Key, Ivec, PlainText, true));
block_encrypt(aes_gcm, Key, Ivec, {AAD, PlainText}) ->
    aes_gcm_encrypt(Key, Ivec, AAD, PlainText);
block_encrypt(aes_gcm, Key, Ivec, {AAD, PlainText, TagLength}) ->
    aes_gcm_encrypt(Key, Ivec, AAD, PlainText, TagLength);
block_encrypt(chacha20_poly1305, Key, Ivec, {AAD, PlainText}) ->
    chacha20_poly1305_encrypt(Key, Ivec, AAD, PlainText).

-spec block_decrypt(Type::block_cipher_with_iv(), Key::key()|des3_key(), Ivec::binary(), Data::iodata()) -> binary();
		   (Type::aead_cipher(), Key::iodata(), Ivec::binary(),
		    {AAD::binary(), Data::iodata(), Tag::binary()}) -> binary() | error.
block_decrypt(Type, Key, Ivec, Data) when Type =:= des_cbc;
                                          Type =:= des_cfb;
                                          Type =:= blowfish_cbc;
                                          Type =:= blowfish_cfb64;
                                          Type =:= blowfish_ofb64;
					  Type =:= aes_cbc;
                                          Type =:= aes_cbc128;
                                          Type =:= aes_cfb8;
                                          Type =:= aes_cfb128;
                                          Type =:= aes_cbc256;
                                          Type =:= rc2_cbc ->
    block_crypt_nif(Type, Key, Ivec, Data, false);
block_decrypt(Type, Key0, Ivec, Data) when Type =:= des3_cbc;
                                           Type =:= des_ede3 ->
    Key = check_des3_key(Key0),
    block_crypt_nif(des_ede3_cbc, Key, Ivec, Data, false);
block_decrypt(des3_cbf, Key0, Ivec, Data) -> % cfb misspelled
    Key = check_des3_key(Key0),
    block_crypt_nif(des_ede3_cbf, Key, Ivec, Data, false);
block_decrypt(des3_cfb, Key0, Ivec, Data) ->
    Key = check_des3_key(Key0),
    block_crypt_nif(des_ede3_cfb, Key, Ivec, Data, false);
block_decrypt(aes_ige256, Key, Ivec, Data) ->
    notsup_to_error(aes_ige_crypt_nif(Key, Ivec, Data, false));
block_decrypt(aes_gcm, Key, Ivec, {AAD, Data, Tag}) ->
    aes_gcm_decrypt(Key, Ivec, AAD, Data, Tag);
block_decrypt(chacha20_poly1305, Key, Ivec, {AAD, Data, Tag}) ->
    chacha20_poly1305_decrypt(Key, Ivec, AAD, Data, Tag).



-spec block_encrypt(Type::block_cipher_without_iv(), Key::key(), PlainText::iodata()) -> binary().

block_encrypt(Type, Key, PlainText) ->
    block_crypt_nif(Type, Key, PlainText, true).


-spec block_decrypt(Type::block_cipher_without_iv(), Key::key(), Data::iodata()) -> binary().

block_decrypt(Type, Key, Data) ->
    block_crypt_nif(Type, Key, Data, false).


-spec next_iv(Type:: cbc_cipher(), Data) -> NextIVec when % Type :: cbc_cipher(), %des_cbc | des3_cbc | aes_cbc | aes_ige,
                                           Data :: iodata(),
                                           NextIVec :: binary().
next_iv(Type, Data) when is_binary(Data) ->
    IVecSize = case Type of
                   des_cbc  -> 8;
                   des3_cbc -> 8;
                   blowfish_cbc -> 8;
                   aes_cbc  -> 16;
                   aes_ige  -> 32; % For compatibility if someone has bug-adapted code
                   aes_ige256 -> 32 % The name used in block_encrypt et al
               end,
    {_, IVec} = split_binary(Data, size(Data) - IVecSize),
    IVec;
next_iv(Type, Data) when is_list(Data) ->
    next_iv(Type, list_to_binary(Data)).

-spec next_iv(des_cfb, Data, IVec) -> NextIVec when Data :: iodata(),
                                                    IVec :: binary(),
                                                    NextIVec :: binary().

next_iv(des_cfb, Data, IVec) ->
    IVecAndData = list_to_binary([IVec, Data]),
    {_, NewIVec} = split_binary(IVecAndData, byte_size(IVecAndData) - 8),
    NewIVec;
next_iv(Type, Data, _Ivec) ->
    next_iv(Type, Data).

%%%---- Stream ciphers

-opaque stream_state() :: {stream_cipher(), reference()}.

-type stream_cipher() :: rc4 | aes_ctr | chacha20 .

-spec stream_init(Type, Key, IVec) -> State when Type :: aes_ctr | chacha20,
                                                 Key :: iodata(),
                                                 IVec :: binary(),
                                                 State :: stream_state() .
stream_init(aes_ctr, Key, Ivec) ->
    {aes_ctr, aes_ctr_stream_init(Key, Ivec)};
stream_init(chacha20, Key, Ivec) ->
    {chacha20, chacha20_stream_init(Key,Ivec)}.

-spec stream_init(Type, Key) -> State when Type :: rc4,
                                           Key :: iodata(),
                                           State :: stream_state() .
stream_init(rc4, Key) ->
    {rc4, notsup_to_error(rc4_set_key(Key))}.

-spec stream_encrypt(State, PlainText) -> {NewState, CipherText}
                                              when State :: stream_state(),
                                                   PlainText :: iodata(),
                                                   NewState :: stream_state(),
                                                   CipherText :: iodata() .
stream_encrypt(State, Data0) ->
    Data = iolist_to_binary(Data0),
    MaxByts = max_bytes(),
    stream_crypt(fun do_stream_encrypt/2, State, Data, erlang:byte_size(Data), MaxByts, []).

-spec stream_decrypt(State, CipherText) -> {NewState, PlainText}
                                              when State :: stream_state(),
                                                   CipherText :: iodata(),
                                                   NewState :: stream_state(),
                                                   PlainText :: iodata() .
stream_decrypt(State, Data0) ->
    Data = iolist_to_binary(Data0),
    MaxByts = max_bytes(),
    stream_crypt(fun do_stream_decrypt/2, State, Data, erlang:byte_size(Data), MaxByts, []).


%%%================================================================
%%%
%%% RAND - pseudo random numbers using RN_ and BN_ functions in crypto lib
%%%
%%%================================================================
-type rand_cache_seed() ::
        nonempty_improper_list(non_neg_integer(), binary()).

-spec strong_rand_bytes(N::non_neg_integer()) -> binary().
strong_rand_bytes(Bytes) ->
    case strong_rand_bytes_nif(Bytes) of
        false -> erlang:error(low_entropy);
        Bin -> Bin
    end.
strong_rand_bytes_nif(_Bytes) -> ?nif_stub.


-spec rand_seed() -> rand:state().
rand_seed() ->
    rand:seed(rand_seed_s()).

-spec rand_seed_s() -> rand:state().
rand_seed_s() ->
    rand_seed_alg_s(?MODULE).

-spec rand_seed_alg(Alg :: atom()) ->
                           {rand:alg_handler(),
                            atom() | rand_cache_seed()}.
rand_seed_alg(Alg) ->
    rand:seed(rand_seed_alg_s(Alg)).

-define(CRYPTO_CACHE_BITS, 56).
-spec rand_seed_alg_s(Alg :: atom()) ->
                             {rand:alg_handler(),
                              atom() | rand_cache_seed()}.
rand_seed_alg_s(?MODULE) ->
    {#{ type => ?MODULE,
        bits => 64,
        next => fun ?MODULE:rand_plugin_next/1,
        uniform => fun ?MODULE:rand_plugin_uniform/1,
        uniform_n => fun ?MODULE:rand_plugin_uniform/2},
     no_seed};
rand_seed_alg_s(crypto_cache) ->
    CacheBits = ?CRYPTO_CACHE_BITS,
    EnvCacheSize =
        application:get_env(
          crypto, rand_cache_size, CacheBits * 16), % Cache 16 * 8 words
    Bytes = (CacheBits + 7) div 8,
    CacheSize =
        case ((EnvCacheSize + (Bytes - 1)) div Bytes) * Bytes of
            Sz when is_integer(Sz), Bytes =< Sz ->
                Sz;
            _ ->
                Bytes
        end,
    {#{ type => crypto_cache,
        bits => CacheBits,
        next => fun ?MODULE:rand_cache_plugin_next/1},
     {CacheBits, CacheSize, <<>>}}.

rand_plugin_next(Seed) ->
    {bytes_to_integer(strong_rand_range(1 bsl 64)), Seed}.

rand_plugin_uniform(State) ->
    {strong_rand_float(), State}.

rand_plugin_uniform(Max, State) ->
    {bytes_to_integer(strong_rand_range(Max)) + 1, State}.

rand_cache_plugin_next({CacheBits, CacheSize, <<>>}) ->
    rand_cache_plugin_next(
      {CacheBits, CacheSize, strong_rand_bytes(CacheSize)});
rand_cache_plugin_next({CacheBits, CacheSize, Cache}) ->
    <<I:CacheBits, NewCache/binary>> = Cache,
    {I, {CacheBits, CacheSize, NewCache}}.

strong_rand_range(Range) when is_integer(Range), Range > 0 ->
    BinRange = int_to_bin(Range),
    strong_rand_range(BinRange);
strong_rand_range(BinRange) when is_binary(BinRange) ->
    case strong_rand_range_nif(BinRange) of
        false ->
            erlang:error(low_entropy);
        <<BinResult/binary>> ->
            BinResult
    end.
strong_rand_range_nif(_BinRange) -> ?nif_stub.

strong_rand_float() ->
    WholeRange = strong_rand_range(1 bsl 53),
    ?HALF_DBL_EPSILON * bytes_to_integer(WholeRange).

-spec rand_uniform(crypto_integer(), crypto_integer()) ->
			  crypto_integer().
rand_uniform(From, To) when is_binary(From), is_binary(To) ->
    case rand_uniform_nif(From,To) of
	<<Len:32/integer, MSB, Rest/binary>> when MSB > 127 ->
	    <<(Len + 1):32/integer, 0, MSB, Rest/binary>>;
	Whatever ->
	    Whatever
    end;
rand_uniform(From,To) when is_integer(From),is_integer(To) ->
    if From < 0 ->
	    rand_uniform_pos(0, To - From) + From;
       true ->
	    rand_uniform_pos(From, To)
    end.

rand_uniform_pos(From,To) when From < To ->
    BinFrom = mpint(From),
    BinTo = mpint(To),
    case rand_uniform(BinFrom, BinTo) of
        Result when is_binary(Result) ->
            erlint(Result);
        Other ->
            Other
    end;
rand_uniform_pos(_,_) ->
    error(badarg).

rand_uniform_nif(_From,_To) -> ?nif_stub.


-spec rand_seed(binary()) -> ok.
rand_seed(Seed) when is_binary(Seed) ->
    rand_seed_nif(Seed).

rand_seed_nif(_Seed) -> ?nif_stub.

%%%================================================================
%%%
%%% Sign/verify
%%%
%%%================================================================
-type pk_sign_verify_algs() :: rsa | dss | ecdsa .

-type pk_sign_verify_opts() :: [ rsa_sign_verify_opt() ] .

-type rsa_sign_verify_opt() :: {rsa_padding, rsa_sign_verify_padding()}
                             | {rsa_pss_saltlen, integer()} .

-type rsa_sign_verify_padding() :: rsa_pkcs1_padding | rsa_pkcs1_pss_padding
                                 | rsa_x931_padding | rsa_no_padding
                                   .


%%%----------------------------------------------------------------
%%% Sign

-spec sign(Algorithm, DigestType, Msg, Key)
          -> Signature 
                 when Algorithm :: pk_sign_verify_algs(),
                      DigestType :: rsa_digest_type()
                                  | dss_digest_type()
                                  | ecdsa_digest_type(),
                      Msg :: binary() | {digest,binary()},
                      Key :: rsa_private()
                           | dss_private()
                           | [ecdsa_private()|ecdsa_params()]
                           | engine_key_ref(),
                      Signature :: binary() .

sign(Algorithm, Type, Data, Key) ->
    sign(Algorithm, Type, Data, Key, []).


-spec sign(Algorithm, DigestType, Msg, Key, Options)
          -> Signature 
                 when Algorithm :: pk_sign_verify_algs(),
                      DigestType :: rsa_digest_type()
                                  | dss_digest_type()
                                  | ecdsa_digest_type()
                                  | none,
                      Msg :: binary() | {digest,binary()},
                      Key :: rsa_private()
                           | dss_private()
                           | [ecdsa_private() | ecdsa_params()]
                           | engine_key_ref(),
                      Options :: pk_sign_verify_opts(),
                      Signature :: binary() .

sign(Algorithm0, Type0, Data, Key, Options) ->
    {Algorithm, Type} = sign_verify_compatibility(Algorithm0, Type0, Data),
    case pkey_sign_nif(Algorithm, Type, Data, format_pkey(Algorithm, Key), Options) of
	error -> erlang:error(badkey, [Algorithm, Type, Data, Key, Options]);
	notsup -> erlang:error(notsup);
	Signature -> Signature
    end.

pkey_sign_nif(_Algorithm, _Type, _Digest, _Key, _Options) -> ?nif_stub.

%%%----------------------------------------------------------------
%%% Verify

-spec verify(Algorithm, DigestType, Msg, Signature, Key)
            -> Result
                   when Algorithm :: pk_sign_verify_algs(),
                        DigestType :: rsa_digest_type()
                                    | dss_digest_type()
                                    | ecdsa_digest_type(),
                        Msg :: binary() | {digest,binary()},
                        Signature :: binary(),
                        Key :: rsa_private()
                             | dss_private()
                             | [ecdsa_private() | ecdsa_params()]
                             | engine_key_ref(),
                        Result :: boolean().

verify(Algorithm, Type, Data, Signature, Key) ->
    verify(Algorithm, Type, Data, Signature, Key, []).

-spec verify(Algorithm, DigestType, Msg, Signature, Key, Options)
            -> Result
                   when Algorithm :: pk_sign_verify_algs(),
                        DigestType :: rsa_digest_type()
                                    | dss_digest_type()
                                    | ecdsa_digest_type(),
                        Msg :: binary() | {digest,binary()},
                        Signature :: binary(),
                        Key :: rsa_public()
                             | dss_public()
                             | [ecdsa_public() | ecdsa_params()]
                             | engine_key_ref(),
                        Options :: pk_sign_verify_opts(),
                        Result :: boolean().

verify(Algorithm0, Type0, Data, Signature, Key, Options) ->
    {Algorithm, Type} = sign_verify_compatibility(Algorithm0, Type0, Data),
    case pkey_verify_nif(Algorithm, Type, Data, Signature, format_pkey(Algorithm, Key), Options) of
	notsup -> erlang:error(notsup);
	Boolean -> Boolean
    end.

pkey_verify_nif(_Algorithm, _Type, _Data, _Signature, _Key, _Options) -> ?nif_stub.

%% Backwards compatible:
sign_verify_compatibility(dss, none, Digest) ->
    {sha, {digest, Digest}};
sign_verify_compatibility(Algorithm0, Type0, _Digest) ->
    {Algorithm0, Type0}.

%%%================================================================
%%%
%%% Public/private encrypt/decrypt
%%%
%%% Only rsa works so far (although ecdsa | dss should do it)
%%%================================================================
-type pk_encrypt_decrypt_algs() :: rsa .

-type pk_encrypt_decrypt_opts() ::  [rsa_opt()] | rsa_compat_opts().

-type rsa_compat_opts() :: [{rsa_pad, rsa_padding()}]
                         | rsa_padding() .

-type rsa_padding() :: rsa_pkcs1_padding
                     | rsa_pkcs1_oaep_padding
                     | rsa_sslv23_padding
                     | rsa_x931_padding
                     | rsa_no_padding.

-type rsa_opt() :: {rsa_padding, rsa_padding()} 
                 | {signature_md, atom()}
                 | {rsa_mgf1_md, sha}
                 | {rsa_oaep_label, binary()}
                 | {rsa_oaep_md, sha} .

%%%---- Encrypt with public key

-spec public_encrypt(Algorithm, PlainText, PublicKey, Options) ->
                            CipherText when Algorithm :: pk_encrypt_decrypt_algs(),
                                            PlainText :: binary(),
                                            PublicKey :: rsa_public() | engine_key_ref(),
                                            Options :: pk_encrypt_decrypt_opts(),
                                            CipherText :: binary().
public_encrypt(Algorithm, PlainText, PublicKey, Options) ->
    pkey_crypt(Algorithm, PlainText, PublicKey, Options, false, true).

%%%---- Decrypt with private key

-spec private_decrypt(Algorithm, CipherText, PrivateKey, Options) ->
                             PlainText when Algorithm :: pk_encrypt_decrypt_algs(),
                                            CipherText :: binary(),
                                            PrivateKey :: rsa_private() | engine_key_ref(),
                                            Options :: pk_encrypt_decrypt_opts(),
                                            PlainText :: binary() .
private_decrypt(Algorithm, CipherText, PrivateKey, Options) ->
    pkey_crypt(Algorithm, CipherText,  PrivateKey, Options, true, false).

%%%---- Encrypt with private key

-spec private_encrypt(Algorithm, PlainText, PrivateKey, Options) ->
                            CipherText when Algorithm :: pk_encrypt_decrypt_algs(),
                                            PlainText :: binary(),
                                            PrivateKey :: rsa_private() | engine_key_ref(),
                                            Options :: pk_encrypt_decrypt_opts(),
                                            CipherText :: binary().
private_encrypt(Algorithm, PlainText, PrivateKey, Options) ->
    pkey_crypt(Algorithm, PlainText,  PrivateKey, Options, true, true).

%%%---- Decrypt with public key

-spec public_decrypt(Algorithm, CipherText, PublicKey, Options) ->
                             PlainText when Algorithm :: pk_encrypt_decrypt_algs(),
                                            CipherText :: binary(),
                                            PublicKey :: rsa_public() | engine_key_ref(),
                                            Options :: pk_encrypt_decrypt_opts(),
                                            PlainText :: binary() .
public_decrypt(Algorithm, CipherText, PublicKey, Options) ->
    pkey_crypt(Algorithm, CipherText, PublicKey, Options, false, false).

%%%---- Call the nif, but fix a compatibility issue first

%% Backwards compatible (rsa_pad -> rsa_padding is handled by the pkey_crypt_nif):
pkey_crypt(rsa, Text, Key, Padding, PubPriv, EncDec) when is_atom(Padding) ->
    pkey_crypt(rsa, Text, Key, [{rsa_padding, Padding}], PubPriv, EncDec);

pkey_crypt(Alg, Text, Key, Options, PubPriv, EncDec) ->
    case pkey_crypt_nif(Alg, Text, format_pkey(Alg,Key), Options, PubPriv, EncDec) of
	error when EncDec==true  -> erlang:error(encrypt_failed, [Alg, Text, Key, Options]);
	error when EncDec==false -> erlang:error(decrypt_failed, [Alg, Text, Key, Options]);
	notsup -> erlang:error(notsup);
	Out -> Out
    end.

pkey_crypt_nif(_Algorithm, _In, _Key, _Options, _IsPrivate, _IsEncrypt) -> ?nif_stub.

%%%================================================================
%%%
%%%
%%%
%%%================================================================

-spec generate_key(Type, Params)
                 -> {PublicKey, PrivKeyOut} 
                        when Type :: dh | ecdh | rsa | srp,
                             PublicKey :: dh_public() | ecdh_public() | rsa_public() | srp_public(),
                             PrivKeyOut :: dh_private() | ecdh_private() | rsa_private() | {srp_public(),srp_private()},
                             Params :: dh_params() | ecdh_params() | rsa_params() | srp_gen_params()
                                       .
generate_key(Type, Params) ->
    generate_key(Type, Params, undefined).

-spec generate_key(Type, Params, PrivKeyIn)
                 -> {PublicKey, PrivKeyOut} 
                        when Type :: dh | ecdh | rsa | srp,
                             PublicKey :: dh_public() | ecdh_public() | rsa_public() | srp_public(),
                             PrivKeyIn :: undefined | dh_private() | ecdh_private() | rsa_private() | {srp_public(),srp_private()},
                             PrivKeyOut :: dh_private() | ecdh_private() | rsa_private() | {srp_public(),srp_private()},
                             Params :: dh_params() | ecdh_params() | rsa_params() | srp_comp_params()
                                       .

generate_key(dh, DHParameters0, PrivateKey) ->
    {DHParameters, Len} =
        case DHParameters0 of
            [P,G,L] -> {[P,G], L};
            [P,G] -> {[P,G], 0}
        end,
    dh_generate_key_nif(ensure_int_as_bin(PrivateKey),
			map_ensure_int_as_bin(DHParameters),
                        0, Len);

generate_key(srp, {host, [Verifier, Generator, Prime, Version]}, PrivArg)
  when is_binary(Verifier), is_binary(Generator), is_binary(Prime), is_atom(Version) ->
    Private = case PrivArg of
		  undefined -> strong_rand_bytes(32);
		  _ -> ensure_int_as_bin(PrivArg)
	      end,
    host_srp_gen_key(Private, Verifier, Generator, Prime, Version);

generate_key(srp, {user, [Generator, Prime, Version]}, PrivateArg)
  when is_binary(Generator), is_binary(Prime), is_atom(Version) ->
    Private = case PrivateArg of
		  undefined -> strong_rand_bytes(32);
		  _ -> PrivateArg
	      end,
    user_srp_gen_key(Private, Generator, Prime);

generate_key(rsa, {ModulusSize, PublicExponent}, undefined) ->
    case rsa_generate_key_nif(ModulusSize, ensure_int_as_bin(PublicExponent)) of
        error ->
            erlang:error(computation_failed,
                         [rsa,{ModulusSize,PublicExponent}]);
        Private ->
            {lists:sublist(Private, 2), Private}
    end;


generate_key(ecdh, Curve, undefined) when Curve == x448 ;
                                          Curve == x25519 ->
    evp_generate_key_nif(Curve);
generate_key(ecdh, Curve, PrivKey) ->
    ec_key_generate(nif_curve_params(Curve), ensure_int_as_bin(PrivKey)).


evp_generate_key_nif(_Curve) -> ?nif_stub.


-spec compute_key(Type, OthersPublicKey, MyPrivateKey, Params)
                 -> SharedSecret
                        when Type :: dh | ecdh | srp,
                             SharedSecret :: binary(),
                             OthersPublicKey :: dh_public() | ecdh_public() | srp_public(),
                             MyPrivateKey :: dh_private() | ecdh_private() | {srp_public(),srp_private()},
                             Params :: dh_params() | ecdh_params() | srp_comp_params()
                                       .

compute_key(dh, OthersPublicKey, MyPrivateKey, DHParameters) ->
    case dh_compute_key_nif(ensure_int_as_bin(OthersPublicKey),
			    ensure_int_as_bin(MyPrivateKey),
			    map_ensure_int_as_bin(DHParameters)) of
	error -> erlang:error(computation_failed,
			      [dh,OthersPublicKey,MyPrivateKey,DHParameters]);
	Ret -> Ret
    end;

compute_key(srp, HostPublic, {UserPublic, UserPrivate},
	    {user, [DerivedKey, Prime, Generator, Version | ScramblerArg]}) when
      is_binary(Prime),
      is_binary(Generator),
      is_atom(Version) ->
    HostPubBin = ensure_int_as_bin(HostPublic),
    Multiplier = srp_multiplier(Version, Generator, Prime),
    Scrambler = case ScramblerArg of
		    [] -> srp_scrambler(Version, ensure_int_as_bin(UserPublic),
					HostPubBin, Prime);
		    [S] -> S
		end,
    notsup_to_error(
    srp_user_secret_nif(ensure_int_as_bin(UserPrivate), Scrambler, HostPubBin,
                          Multiplier, Generator, DerivedKey, Prime));

compute_key(srp, UserPublic, {HostPublic, HostPrivate},
	    {host,[Verifier, Prime, Version | ScramblerArg]}) when
      is_binary(Verifier),
      is_binary(Prime),
      is_atom(Version) ->
    UserPubBin = ensure_int_as_bin(UserPublic),
    Scrambler = case ScramblerArg of
		    [] -> srp_scrambler(Version, UserPubBin, ensure_int_as_bin(HostPublic), Prime);
		    [S] -> S
		end,
    notsup_to_error(
    srp_host_secret_nif(Verifier, ensure_int_as_bin(HostPrivate), Scrambler,
                          UserPubBin, Prime));

compute_key(ecdh, Others, My, Curve) when Curve == x448 ;
                                          Curve == x25519 ->
    evp_compute_key_nif(Curve, ensure_int_as_bin(Others), ensure_int_as_bin(My));

compute_key(ecdh, Others, My, Curve) ->
    ecdh_compute_key_nif(ensure_int_as_bin(Others),
			 nif_curve_params(Curve),
			 ensure_int_as_bin(My)).


evp_compute_key_nif(_Curve, _OthersBin, _MyBin) -> ?nif_stub.


%%%================================================================
%%%
%%% XOR - xor to iolists and return a binary
%%% NB doesn't check that they are the same size, just concatenates
%%% them and sends them to the driver
%%%
%%%================================================================

-spec exor(iodata(), iodata()) -> binary().

exor(Bin1, Bin2) ->
    Data1 = iolist_to_binary(Bin1),
    Data2 = iolist_to_binary(Bin2),
    MaxBytes = max_bytes(),
    exor(Data1, Data2, erlang:byte_size(Data1), MaxBytes, []).


%%%================================================================
%%%
%%% Exponentiation modulo
%%%
%%%================================================================

-spec mod_pow(N, P, M) -> Result when N :: binary() | integer(),
                                      P :: binary() | integer(),
                                      M :: binary() | integer(),
                                      Result :: binary() | error .
mod_pow(Base, Exponent, Prime) ->
    case mod_exp_nif(ensure_int_as_bin(Base), ensure_int_as_bin(Exponent), ensure_int_as_bin(Prime), 0) of
	<<0>> -> error;
	R -> R
    end.

%%%======================================================================
%%%
%%% Engine functions
%%% 
%%%======================================================================

%%%---- Refering to keys stored in an engine:
-type key_id()   :: string() | binary() .
-type password() :: string() | binary() .

-type engine_key_ref() :: #{engine :=   engine_ref(),
                            key_id :=   key_id(),
                            password => password(),
                            term() => term()
                           }.

%%%---- Commands:
-type engine_cmnd() :: {unicode:chardata(), unicode:chardata()}.

%%----------------------------------------------------------------------
%% Function: engine_get_all_methods/0
%%----------------------------------------------------------------------
-type engine_method_type() :: engine_method_rsa | engine_method_dsa | engine_method_dh |
                              engine_method_rand | engine_method_ecdh | engine_method_ecdsa |
                              engine_method_ciphers | engine_method_digests | engine_method_store |
                              engine_method_pkey_meths | engine_method_pkey_asn1_meths |
                              engine_method_ec.

-type engine_ref() :: term().

-spec engine_get_all_methods() -> Result when Result :: [engine_method_type()].
engine_get_all_methods() ->
     notsup_to_error(engine_get_all_methods_nif()).

%%----------------------------------------------------------------------
%% Function: engine_load/3
%%----------------------------------------------------------------------
-spec engine_load(EngineId, PreCmds, PostCmds) ->
                         Result when EngineId::unicode:chardata(),
                                     PreCmds::[engine_cmnd()],
                                     PostCmds::[engine_cmnd()],
                                     Result :: {ok, Engine::engine_ref()} | {error, Reason::term()}.
engine_load(EngineId, PreCmds, PostCmds) when is_list(PreCmds),
                                              is_list(PostCmds) ->
    engine_load(EngineId, PreCmds, PostCmds, engine_get_all_methods()).

%%----------------------------------------------------------------------
%% Function: engine_load/4
%%----------------------------------------------------------------------
-spec engine_load(EngineId, PreCmds, PostCmds, EngineMethods) ->
                         Result when EngineId::unicode:chardata(),
                                     PreCmds::[engine_cmnd()],
                                     PostCmds::[engine_cmnd()],
                                     EngineMethods::[engine_method_type()],
                                     Result :: {ok, Engine::engine_ref()} | {error, Reason::term()}.
engine_load(EngineId, PreCmds, PostCmds, EngineMethods) when is_list(PreCmds),
                                                             is_list(PostCmds) ->
    try
        ok = notsup_to_error(engine_load_dynamic_nif()),
        case notsup_to_error(engine_by_id_nif(ensure_bin_chardata(EngineId))) of
            {ok, Engine} ->
                engine_load_1(Engine, PreCmds, PostCmds, EngineMethods);
            {error, Error1} ->
                {error, Error1}
        end
    catch
        throw:Error2 ->
            Error2
    end.

engine_load_1(Engine, PreCmds, PostCmds, EngineMethods) ->
    try
        ok = engine_nif_wrapper(engine_ctrl_cmd_strings_nif(Engine, ensure_bin_cmds(PreCmds), 0)),
        ok = engine_nif_wrapper(engine_init_nif(Engine)),
        engine_load_2(Engine, PostCmds, EngineMethods),
        {ok, Engine}
    catch
        throw:Error ->
            %% The engine couldn't initialise, release the structural reference
            ok = engine_free_nif(Engine),
            throw(Error)
    end.

engine_load_2(Engine, PostCmds, EngineMethods) ->
    try
        ok = engine_nif_wrapper(engine_ctrl_cmd_strings_nif(Engine, ensure_bin_cmds(PostCmds), 0)),
        [ok = engine_nif_wrapper(engine_register_nif(Engine, engine_method_atom_to_int(Method))) ||
            Method <- EngineMethods],
        ok
    catch
       throw:Error ->
          %% The engine registration failed, release the functional reference
          ok = engine_finish_nif(Engine),
          throw(Error)
    end.

%%----------------------------------------------------------------------
%% Function: engine_unload/1
%%----------------------------------------------------------------------
-spec engine_unload(Engine) -> Result when Engine :: engine_ref(),
                                           Result :: ok | {error, Reason::term()}.
engine_unload(Engine) ->
    engine_unload(Engine, engine_get_all_methods()).

-spec engine_unload(Engine, EngineMethods) -> Result when Engine :: engine_ref(),
                                                          EngineMethods :: [engine_method_type()],
                                                          Result :: ok | {error, Reason::term()}.
engine_unload(Engine, EngineMethods) ->
    try
        [ok = engine_nif_wrapper(engine_unregister_nif(Engine, engine_method_atom_to_int(Method))) ||
            Method <- EngineMethods],
        %% Release the functional reference from engine_init_nif
        ok = engine_nif_wrapper(engine_finish_nif(Engine)),
        %% Release the structural reference from engine_by_id_nif
        ok = engine_nif_wrapper(engine_free_nif(Engine))
    catch
       throw:Error ->
          Error
    end.

%%----------------------------------------------------------------------
%% Function: engine_by_id/1
%%----------------------------------------------------------------------
-spec engine_by_id(EngineId) -> Result when EngineId :: unicode:chardata(),
                                            Result :: {ok, Engine::engine_ref()} | {error, Reason::term()} .
engine_by_id(EngineId) ->
    try
        notsup_to_error(engine_by_id_nif(ensure_bin_chardata(EngineId)))
    catch
       throw:Error ->
          Error
    end.

%%----------------------------------------------------------------------
%% Function: engine_add/1
%%----------------------------------------------------------------------
-spec engine_add(Engine) -> Result when Engine :: engine_ref(),
                                        Result ::  ok | {error, Reason::term()} .
engine_add(Engine) ->
    notsup_to_error(engine_add_nif(Engine)).

%%----------------------------------------------------------------------
%% Function: engine_remove/1
%%----------------------------------------------------------------------
-spec engine_remove(Engine) -> Result when Engine :: engine_ref(),
                                           Result ::  ok | {error, Reason::term()} .
engine_remove(Engine) ->
    notsup_to_error(engine_remove_nif(Engine)).

%%----------------------------------------------------------------------
%% Function: engine_get_id/1
%%----------------------------------------------------------------------
-spec engine_get_id(Engine) -> EngineId when Engine :: engine_ref(),
                                             EngineId :: unicode:chardata().
engine_get_id(Engine) ->
    notsup_to_error(engine_get_id_nif(Engine)).

%%----------------------------------------------------------------------
%% Function: engine_get_name/1
%%----------------------------------------------------------------------
-spec engine_get_name(Engine) -> EngineName when Engine :: engine_ref(),
                                                 EngineName :: unicode:chardata().
engine_get_name(Engine) ->
    notsup_to_error(engine_get_name_nif(Engine)).

%%----------------------------------------------------------------------
%% Function: engine_list/0
%%----------------------------------------------------------------------
-spec engine_list() -> Result when Result :: [EngineId::unicode:chardata()].
engine_list() ->
    case notsup_to_error(engine_get_first_nif()) of
        {ok, <<>>} ->
            [];
        {ok, Engine} ->
            case notsup_to_error(engine_get_id_nif(Engine)) of
                <<>> ->
                    engine_list(Engine, []);
                EngineId ->
                    engine_list(Engine, [EngineId])
            end
    end.

engine_list(Engine0, IdList) ->
    case notsup_to_error(engine_get_next_nif(Engine0)) of
        {ok, <<>>} ->
            lists:reverse(IdList);
        {ok, Engine1} ->
            case notsup_to_error(engine_get_id_nif(Engine1)) of
                <<>> ->
                    engine_list(Engine1, IdList);
                EngineId ->
                    engine_list(Engine1, [EngineId |IdList])
            end
    end.

%%----------------------------------------------------------------------
%% Function: engine_ctrl_cmd_string/3
%%----------------------------------------------------------------------
-spec engine_ctrl_cmd_string(Engine, CmdName, CmdArg) ->
                                    Result when Engine::term(),
                                                CmdName::unicode:chardata(),
                                                CmdArg::unicode:chardata(),
                                                Result :: ok | {error, Reason::term()}.
engine_ctrl_cmd_string(Engine, CmdName, CmdArg) ->
    engine_ctrl_cmd_string(Engine, CmdName, CmdArg, false).

%%----------------------------------------------------------------------
%% Function: engine_ctrl_cmd_string/4
%%----------------------------------------------------------------------
-spec engine_ctrl_cmd_string(Engine, CmdName, CmdArg, Optional) ->
                                    Result when Engine::term(),
                                                CmdName::unicode:chardata(),
                                                CmdArg::unicode:chardata(),
                                                Optional::boolean(),
                                                Result :: ok | {error, Reason::term()}.
engine_ctrl_cmd_string(Engine, CmdName, CmdArg, Optional) ->
    case engine_ctrl_cmd_strings_nif(Engine,
                                     ensure_bin_cmds([{CmdName, CmdArg}]),
                                     bool_to_int(Optional)) of
        ok ->
            ok;
        notsup ->
            erlang:error(notsup);
        {error, Error} ->
            {error, Error}
    end.

%%----------------------------------------------------------------------
%% Function: ensure_engine_loaded/2
%% Special version of load that only uses dynamic engine to load
%%----------------------------------------------------------------------
-spec ensure_engine_loaded(EngineId, LibPath) ->
                                  Result when EngineId :: unicode:chardata(),
                                              LibPath :: unicode:chardata(),
                                              Result :: {ok, Engine::engine_ref()} | {error, Reason::term()}.
ensure_engine_loaded(EngineId, LibPath) ->
    ensure_engine_loaded(EngineId, LibPath, engine_get_all_methods()).

%%----------------------------------------------------------------------
%% Function: ensure_engine_loaded/3
%% Special version of load that only uses dynamic engine to load
%%----------------------------------------------------------------------
-spec ensure_engine_loaded(EngineId, LibPath, EngineMethods) ->
                                  Result when EngineId :: unicode:chardata(),
                                              LibPath :: unicode:chardata(),
                                              EngineMethods :: [engine_method_type()],
                                              Result :: {ok, Engine::engine_ref()} | {error, Reason::term()}.
ensure_engine_loaded(EngineId, LibPath, EngineMethods) ->
    try
        List = crypto:engine_list(),
        case lists:member(EngineId, List) of
            true ->
                notsup_to_error(engine_by_id_nif(ensure_bin_chardata(EngineId)));
            false ->
                ok = notsup_to_error(engine_load_dynamic_nif()),
                case notsup_to_error(engine_by_id_nif(ensure_bin_chardata(<<"dynamic">>))) of
                    {ok, Engine} ->
                        PreCommands = [{<<"SO_PATH">>, ensure_bin_chardata(LibPath)},
                                       {<<"ID">>, ensure_bin_chardata(EngineId)},
                                       <<"LOAD">>],
                        ensure_engine_loaded_1(Engine, PreCommands, EngineMethods);
                    {error, Error1} ->
                        {error, Error1}
                end
        end
    catch
        throw:Error2 ->
            Error2
    end.

ensure_engine_loaded_1(Engine, PreCmds, Methods) ->
    try
        ok = engine_nif_wrapper(engine_ctrl_cmd_strings_nif(Engine, ensure_bin_cmds(PreCmds), 0)),
        ok = engine_nif_wrapper(engine_add_nif(Engine)),
        ok = engine_nif_wrapper(engine_init_nif(Engine)),
        ensure_engine_loaded_2(Engine, Methods),
        {ok, Engine}
    catch
        throw:Error ->
            %% The engine couldn't initialise, release the structural reference
            ok = engine_free_nif(Engine),
            throw(Error)
    end.

ensure_engine_loaded_2(Engine, Methods) ->
    try
        [ok = engine_nif_wrapper(engine_register_nif(Engine, engine_method_atom_to_int(Method))) ||
            Method <- Methods],
        ok
    catch
       throw:Error ->
          %% The engine registration failed, release the functional reference
          ok = engine_finish_nif(Engine),
          throw(Error)
    end.
%%----------------------------------------------------------------------
%% Function: ensure_engine_unloaded/1
%%----------------------------------------------------------------------
-spec ensure_engine_unloaded(Engine) -> Result when Engine :: engine_ref(),
                                                    Result :: ok | {error, Reason::term()}.
ensure_engine_unloaded(Engine) ->
    ensure_engine_unloaded(Engine, engine_get_all_methods()).

%%----------------------------------------------------------------------
%% Function: ensure_engine_unloaded/2
%%----------------------------------------------------------------------
-spec ensure_engine_unloaded(Engine, EngineMethods) -> 
                                    Result when Engine :: engine_ref(),
                                                EngineMethods :: [engine_method_type()],
                                                Result :: ok | {error, Reason::term()}.
ensure_engine_unloaded(Engine, EngineMethods) ->
    case engine_remove(Engine) of
        ok ->
            engine_unload(Engine, EngineMethods);
        {error, E} ->
            {error, E}
    end.

%%--------------------------------------------------------------------
%%% On load
%%--------------------------------------------------------------------
on_load() ->
    LibBaseName = "crypto",
    PrivDir = code:priv_dir(crypto),
    LibName = case erlang:system_info(build_type) of
		  opt ->
		      LibBaseName;
		  Type ->
		      LibTypeName = LibBaseName ++ "."  ++ atom_to_list(Type),
		      case (filelib:wildcard(
			      filename:join(
				[PrivDir,
				 "lib",
				 LibTypeName ++ "*"])) /= []) orelse
			  (filelib:wildcard(
			     filename:join(
			       [PrivDir,
				"lib",
				erlang:system_info(system_architecture),
				LibTypeName ++ "*"])) /= []) of
			  true -> LibTypeName;
			  false -> LibBaseName
		      end
	      end,
    Lib = filename:join([PrivDir, "lib", LibName]),
    LibBin   = path2bin(Lib),
    FipsMode = application:get_env(crypto, fips_mode, false) == true,
    Status = case erlang:load_nif(Lib, {?CRYPTO_NIF_VSN,LibBin,FipsMode}) of
		 ok -> ok;
		 {error, {load_failed, _}}=Error1 ->
		     ArchLibDir =
			 filename:join([PrivDir, "lib",
					erlang:system_info(system_architecture)]),
		     Candidate =
			 filelib:wildcard(filename:join([ArchLibDir,LibName ++ "*" ])),
		     case Candidate of
			 [] -> Error1;
			 _ ->
			     ArchLib = filename:join([ArchLibDir, LibName]),
                             ArchBin = path2bin(ArchLib),
			     erlang:load_nif(ArchLib, {?CRYPTO_NIF_VSN,ArchBin,FipsMode})
		     end;
		 Error1 -> Error1
	     end,
    case Status of
	ok -> ok;
	{error, {E, Str}} ->
            Fmt = "Unable to load crypto library. Failed with error:~n\"~p, ~s\"~n~s",
            Extra = case E of
                        load_failed ->
                            "OpenSSL might not be installed on this system.\n";
                        _ -> ""
                    end,
	    error_logger:error_msg(Fmt, [E,Str,Extra]),
	    Status
    end.

path2bin(Path) when is_list(Path) ->
    Encoding = file:native_name_encoding(),
    case unicode:characters_to_binary(Path,Encoding,Encoding) of
	Bin when is_binary(Bin) ->
	    Bin
    end.

%%%================================================================
%%%================================================================
%%%
%%% Internal functions
%%% 
%%%================================================================

max_bytes() ->
    ?MAX_BYTES_TO_NIF.

notsup_to_error(notsup) ->
    erlang:error(notsup);
notsup_to_error(Other) ->
    Other.

%% HASH --------------------------------------------------------------------
hash(Hash, Data, Size, Max) when Size =< Max ->
    notsup_to_error(hash_nif(Hash, Data));
hash(Hash, Data, Size, Max) ->
    State0 = hash_init(Hash),
    State1 = hash_update(State0, Data, Size, Max),
    hash_final(State1).

hash_update(State, Data, Size, MaxBytes)  when Size =< MaxBytes ->
    notsup_to_error(hash_update_nif(State, Data));
hash_update(State0, Data, _, MaxBytes) ->
    <<Increment:MaxBytes/binary, Rest/binary>> = Data,
    State = notsup_to_error(hash_update_nif(State0, Increment)),
    hash_update(State, Rest, erlang:byte_size(Rest), MaxBytes).

hash_nif(_Hash, _Data) -> ?nif_stub.
hash_init_nif(_Hash) -> ?nif_stub.
hash_update_nif(_State, _Data) -> ?nif_stub.
hash_final_nif(_State) -> ?nif_stub.

%% HMAC --------------------------------------------------------------------

hmac(Type, Key, Data, MacSize, Size, MaxBytes) when Size =< MaxBytes ->
    notsup_to_error(
    case MacSize of
          undefined -> hmac_nif(Type, Key, Data);
          _         -> hmac_nif(Type, Key, Data, MacSize)
      end);
hmac(Type, Key, Data, MacSize, Size, MaxBytes) ->
    State0 = hmac_init(Type, Key),
    State1 = hmac_update(State0, Data, Size, MaxBytes),
    case MacSize of
        undefined -> hmac_final(State1);
        _         -> hmac_final_n(State1, MacSize)
    end.

hmac_update(State, Data, Size, MaxBytes)  when Size =< MaxBytes ->
    notsup_to_error(hmac_update_nif(State, Data));
hmac_update(State0, Data, _, MaxBytes) ->
    <<Increment:MaxBytes/binary, Rest/binary>> = Data,
    State = notsup_to_error(hmac_update_nif(State0, Increment)),
    hmac_update(State, Rest, erlang:byte_size(Rest), MaxBytes).

hmac_nif(_Type, _Key, _Data) -> ?nif_stub.
hmac_nif(_Type, _Key, _Data, _MacSize) -> ?nif_stub.
hmac_init_nif(_Type, _Key) -> ?nif_stub.
hmac_update_nif(_Context, _Data) -> ?nif_stub.
hmac_final_nif(_Context) -> ?nif_stub.
hmac_final_nif(_Context, _MacSize) -> ?nif_stub.

%% CMAC
cmac_nif(_Type, _Key, _Data) -> ?nif_stub.

%% POLY1305
poly1305_nif(_Key, _Data) -> ?nif_stub.


%% CIPHERS --------------------------------------------------------------------

block_crypt_nif(_Type, _Key, _Ivec, _Text, _IsEncrypt) -> ?nif_stub.
block_crypt_nif(_Type, _Key, _Text, _IsEncrypt) -> ?nif_stub.

check_des3_key(Key) ->
    case lists:map(fun erlang:iolist_to_binary/1, Key) of
        ValidKey = [B1, B2, B3] when byte_size(B1) =:= 8,
                                     byte_size(B2) =:= 8,
                                     byte_size(B3) =:= 8 ->
            ValidKey;
        _ ->
            error(badarg)
   end.

%%
%% AES - in Galois/Counter Mode (GCM)
%%
%% The default tag length is EVP_GCM_TLS_TAG_LEN(16),
aes_gcm_encrypt(Key, Ivec, AAD, In) ->
    aes_gcm_encrypt(Key, Ivec, AAD, In, 16).
aes_gcm_encrypt(_Key, _Ivec, _AAD, _In, _TagLength) -> ?nif_stub.
aes_gcm_decrypt(_Key, _Ivec, _AAD, _In, _Tag) -> ?nif_stub.

%%
%% Chacha20/Ppoly1305
%%
chacha20_poly1305_encrypt(_Key, _Ivec, _AAD, _In) -> ?nif_stub.
chacha20_poly1305_decrypt(_Key, _Ivec, _AAD, _In, _Tag) -> ?nif_stub.

%%
%% AES - with 256 bit key in infinite garble extension mode (IGE)
%%

aes_ige_crypt_nif(_Key, _IVec, _Data, _IsEncrypt) -> ?nif_stub.


%% Stream ciphers --------------------------------------------------------------------

stream_crypt(Fun, State, Data, Size, MaxByts, []) when Size =< MaxByts ->
    Fun(State, Data);
stream_crypt(Fun, State0, Data, Size, MaxByts, Acc) when Size =< MaxByts ->
    {State, Cipher} = Fun(State0, Data),
    {State, list_to_binary(lists:reverse([Cipher | Acc]))};
stream_crypt(Fun, State0, Data, _, MaxByts, Acc) ->
    <<Increment:MaxByts/binary, Rest/binary>> = Data,
    {State, CipherText} = Fun(State0, Increment),
    stream_crypt(Fun, State, Rest, erlang:byte_size(Rest), MaxByts, [CipherText | Acc]).

do_stream_encrypt({aes_ctr, State0}, Data) ->
    {State, Cipher} = aes_ctr_stream_encrypt(State0, Data),
    {{aes_ctr, State}, Cipher};
do_stream_encrypt({rc4, State0}, Data) ->
    {State, Cipher} = rc4_encrypt_with_state(State0, Data),
    {{rc4, State}, Cipher};
do_stream_encrypt({chacha20, State0}, Data) ->
    {State, Cipher} = chacha20_stream_encrypt(State0, Data),
    {{chacha20, State}, Cipher}.

do_stream_decrypt({aes_ctr, State0}, Data) ->
    {State, Text} = aes_ctr_stream_decrypt(State0, Data),
    {{aes_ctr, State}, Text};
do_stream_decrypt({rc4, State0}, Data) ->
    {State, Text} = rc4_encrypt_with_state(State0, Data),
    {{rc4, State}, Text};
do_stream_decrypt({chacha20, State0}, Data) ->
    {State, Cipher} = chacha20_stream_decrypt(State0, Data),
    {{chacha20, State}, Cipher}.


%%
%% AES - in counter mode (CTR) with state maintained for multi-call streaming
%%
aes_ctr_stream_init(_Key, _IVec) -> ?nif_stub.
aes_ctr_stream_encrypt(_State, _Data) -> ?nif_stub.
aes_ctr_stream_decrypt(_State, _Cipher) -> ?nif_stub.

%%
%% RC4 - symmetric stream cipher
%%
rc4_set_key(_Key) -> ?nif_stub.
rc4_encrypt_with_state(_State, _Data) -> ?nif_stub.

%%
%% CHACHA20 - stream cipher
%%
chacha20_stream_init(_Key, _IVec) -> ?nif_stub.
chacha20_stream_encrypt(_State, _Data) -> ?nif_stub.
chacha20_stream_decrypt(_State, _Data) -> ?nif_stub.

%% Secure remote password  -------------------------------------------------------------------

user_srp_gen_key(Private, Generator, Prime) ->
    %% Ensure the SRP algorithm is disabled in FIPS mode
    case info_fips() of
        enabled -> erlang:error(notsup);
        _       -> ok
    end,
    case mod_pow(Generator, Private, Prime) of
	error ->
	    error;
	Public ->
	    {Public, Private}
    end.

host_srp_gen_key(Private, Verifier, Generator, Prime, Version) ->
 Multiplier = srp_multiplier(Version, Generator, Prime),
   case srp_value_B_nif(Multiplier, Verifier, Generator, Private, Prime) of
   error ->
       error;
   notsup ->
       erlang:error(notsup);
   Public ->
       {Public, Private}
   end.

srp_multiplier('6a', Generator, Prime) ->
    %% k = SHA1(N | PAD(g)) from http://srp.stanford.edu/design.html
    C0 = hash_init(sha),
    C1 = hash_update(C0, Prime),
    C2 = hash_update(C1, srp_pad_to(erlang:byte_size(Prime), Generator)),
    hash_final(C2);
srp_multiplier('6', _, _) ->
    <<3/integer>>;
srp_multiplier('3', _, _) ->
    <<1/integer>>.

srp_scrambler(Version, UserPublic, HostPublic, Prime) when Version == '6'; Version == '6a'->
    %% SHA1(PAD(A) | PAD(B)) from http://srp.stanford.edu/design.html
    PadLength = erlang:byte_size(Prime),
    C0 = hash_init(sha),
    C1 = hash_update(C0, srp_pad_to(PadLength, UserPublic)),
    C2 = hash_update(C1, srp_pad_to(PadLength, HostPublic)),
    hash_final(C2);
srp_scrambler('3', _, HostPublic, _Prime) ->
    %% The parameter u is a 32-bit unsigned integer which takes its value
    %% from the first 32 bits of the SHA1 hash of B, MSB first.
    <<U:32/bits, _/binary>> = hash(sha, HostPublic),
    U.

srp_pad_length(Width, Length) ->
    (Width - Length rem Width) rem Width.

srp_pad_to(Width, Binary) ->
    case srp_pad_length(Width, size(Binary)) of
        0 -> Binary;
        N -> << 0:(N*8), Binary/binary>>
    end.

srp_host_secret_nif(_Verifier, _B, _U, _A, _Prime) -> ?nif_stub.

srp_user_secret_nif(_A, _U, _B, _Multiplier, _Generator, _Exponent, _Prime) -> ?nif_stub.

srp_value_B_nif(_Multiplier, _Verifier, _Generator, _Exponent, _Prime) -> ?nif_stub.


%% Public Keys  --------------------------------------------------------------------
%% RSA Rivest-Shamir-Adleman functions
%%

rsa_generate_key_nif(_Bits, _Exp) -> ?nif_stub.

%% DH Diffie-Hellman functions
%%

%% DHParameters = [P (Prime)= mpint(), G(Generator) = mpint()]
%% PrivKey = mpint()
dh_generate_key_nif(_PrivateKey, _DHParameters, _Mpint, _Length) -> ?nif_stub.

%% DHParameters = [P (Prime)= mpint(), G(Generator) = mpint()]
%% MyPrivKey, OthersPublicKey = mpint()
dh_compute_key_nif(_OthersPublicKey, _MyPrivateKey, _DHParameters) -> ?nif_stub.

ec_key_generate(_Curve, _Key) -> ?nif_stub.

ecdh_compute_key_nif(_Others, _Curve, _My) -> ?nif_stub.

-spec ec_curves() -> [EllipticCurve] when EllipticCurve :: ec_named_curve() | edwards_curve() .

ec_curves() ->
    crypto_ec_curves:curves().

-spec ec_curve(CurveName) -> ExplicitCurve when CurveName :: ec_named_curve(),
                                                ExplicitCurve :: ec_explicit_curve() .
ec_curve(X) ->
    crypto_ec_curves:curve(X).


-spec privkey_to_pubkey(Type, EnginePrivateKeyRef) -> PublicKey when Type :: rsa | dss,
                                                                     EnginePrivateKeyRef :: engine_key_ref(),
                                                                     PublicKey ::  rsa_public() | dss_public() .
privkey_to_pubkey(Alg, EngineMap) when Alg == rsa; Alg == dss; Alg == ecdsa ->
    try privkey_to_pubkey_nif(Alg, format_pkey(Alg,EngineMap))
    of
        [_|_]=L -> map_ensure_bin_as_int(L);
        X -> X
    catch
        error:badarg when Alg==ecdsa ->
            {error, notsup};
        error:badarg ->
            {error, not_found};
        error:notsup ->
            {error, notsup}
    end.

privkey_to_pubkey_nif(_Alg, _EngineMap) -> ?nif_stub.


%%
%% EC
%%

term_to_nif_prime({prime_field, Prime}) ->
    {prime_field, ensure_int_as_bin(Prime)};
term_to_nif_prime(PrimeField) ->
    PrimeField.

term_to_nif_curve({A, B, Seed}) ->
    {ensure_int_as_bin(A), ensure_int_as_bin(B), Seed}.

nif_curve_params({PrimeField, Curve, BasePoint, Order, CoFactor}) ->
    {term_to_nif_prime(PrimeField),
     term_to_nif_curve(Curve),
     ensure_int_as_bin(BasePoint),
     ensure_int_as_bin(Order),
     ensure_int_as_bin(CoFactor)};
nif_curve_params(Curve) when is_atom(Curve) ->
    %% named curve
    case Curve of
        x448 -> {evp,Curve};
        x25519 -> {evp,Curve};
        _ -> crypto_ec_curves:curve(Curve)
    end.


%% MISC --------------------------------------------------------------------

exor(Data1, Data2, Size, MaxByts, [])  when Size =< MaxByts ->
    do_exor(Data1, Data2);
exor(Data1, Data2, Size, MaxByts, Acc) when Size =< MaxByts ->
    Result = do_exor(Data1, Data2),
    list_to_binary(lists:reverse([Result | Acc]));
exor(Data1, Data2, _Size, MaxByts, Acc) ->
     <<Increment1:MaxByts/binary, Rest1/binary>> = Data1,
     <<Increment2:MaxByts/binary, Rest2/binary>> = Data2,
    Result = do_exor(Increment1, Increment2),
    exor(Rest1, Rest2, erlang:byte_size(Rest1), MaxByts, [Result | Acc]).

do_exor(_A, _B) -> ?nif_stub.

algorithms() -> ?nif_stub.

int_to_bin(X) when X < 0 -> int_to_bin_neg(X, []);
int_to_bin(X) -> int_to_bin_pos(X, []).

int_to_bin_pos(0,Ds=[_|_]) ->
    list_to_binary(Ds);
int_to_bin_pos(X,Ds) ->
    int_to_bin_pos(X bsr 8, [(X band 255)|Ds]).

int_to_bin_neg(-1, Ds=[MSB|_]) when MSB >= 16#80 ->
    list_to_binary(Ds);
int_to_bin_neg(X,Ds) ->
    int_to_bin_neg(X bsr 8, [(X band 255)|Ds]).

-spec bytes_to_integer(binary()) -> integer() .
bytes_to_integer(Bin) ->
    bin_to_int(Bin).

bin_to_int(Bin) when is_binary(Bin) ->
    Bits = bit_size(Bin),
    <<Integer:Bits/integer>> = Bin,
    Integer;
bin_to_int(undefined) ->
    undefined.

map_ensure_int_as_bin([H|_]=List) when is_integer(H) ->
    lists:map(fun(E) -> int_to_bin(E) end, List);
map_ensure_int_as_bin(List) ->
    List.

ensure_int_as_bin(Int) when is_integer(Int) ->
    int_to_bin(Int);
ensure_int_as_bin(Bin) ->
    Bin.

map_ensure_bin_as_int(List) when is_list(List) ->
    lists:map(fun ensure_bin_as_int/1, List).

ensure_bin_as_int(Bin) when is_binary(Bin) ->
    bin_to_int(Bin);
ensure_bin_as_int(E) ->
    E.

format_pkey(_Alg, #{engine:=_, key_id:=T}=M) when is_binary(T) -> format_pwd(M);
format_pkey(_Alg, #{engine:=_, key_id:=T}=M) when is_list(T) -> format_pwd(M#{key_id:=list_to_binary(T)});
format_pkey(_Alg, #{engine:=_           }=M) -> error({bad_key_id, M});
format_pkey(_Alg, #{}=M) -> error({bad_engine_map, M});
%%%
format_pkey(rsa, Key) ->
    map_ensure_int_as_bin(Key);
format_pkey(ecdsa, [Key, Curve]) ->
    {nif_curve_params(Curve), ensure_int_as_bin(Key)};
format_pkey(dss, Key) ->
    map_ensure_int_as_bin(Key);
format_pkey(_, Key) ->
    Key.

format_pwd(#{password := Pwd}=M) when is_list(Pwd) -> M#{password := list_to_binary(Pwd)};
format_pwd(M) -> M.

%%--------------------------------------------------------------------
%%

%% large integer in a binary with 32bit length
%% MP representaion  (SSH2)
mpint(X) when X < 0 -> mpint_neg(X);
mpint(X) -> mpint_pos(X).

-define(UINT32(X),   X:32/unsigned-big-integer).


mpint_neg(X) ->
    Bin = int_to_bin_neg(X, []),
    Sz = byte_size(Bin),
    <<?UINT32(Sz), Bin/binary>>.

mpint_pos(X) ->
    Bin = int_to_bin_pos(X, []),
    <<MSB,_/binary>> = Bin,
    Sz = byte_size(Bin),
    if MSB band 16#80 == 16#80 ->
	    <<?UINT32((Sz+1)), 0, Bin/binary>>;
       true ->
	    <<?UINT32(Sz), Bin/binary>>
    end.

%% int from integer in a binary with 32bit length
erlint(<<MPIntSize:32/integer,MPIntValue/binary>>) ->
    Bits= MPIntSize * 8,
    <<Integer:Bits/integer>> = MPIntValue,
    Integer.

%%
%% mod_exp - utility for rsa generation and SRP
%%
mod_exp_nif(_Base,_Exp,_Mod,_bin_hdr) -> ?nif_stub.

%%%----------------------------------------------------------------
%% 9470495 == V(0,9,8,zh).
%% 268435615 == V(1,0,0,i).
%% 268439663 == V(1,0,1,f).

packed_openssl_version(MAJ, MIN, FIX, P0) ->
    %% crypto.c
    P1 = atom_to_list(P0),
    P = lists:sum([C-$a||C<-P1]),
    ((((((((MAJ bsl 8) bor MIN) bsl 8 ) bor FIX) bsl 8) bor (P+1)) bsl 4) bor 16#f).

%%--------------------------------------------------------------------
%% Engine nifs
engine_by_id_nif(_EngineId) -> ?nif_stub.
engine_init_nif(_Engine) -> ?nif_stub.
engine_finish_nif(_Engine) -> ?nif_stub.
engine_free_nif(_Engine) -> ?nif_stub.
engine_load_dynamic_nif() -> ?nif_stub.
engine_ctrl_cmd_strings_nif(_Engine, _Cmds, _Optional) -> ?nif_stub.
engine_add_nif(_Engine)  -> ?nif_stub.
engine_remove_nif(_Engine)  -> ?nif_stub.
engine_register_nif(_Engine, _EngineMethod) -> ?nif_stub.
engine_unregister_nif(_Engine, _EngineMethod) -> ?nif_stub.
engine_get_first_nif() -> ?nif_stub.
engine_get_next_nif(_Engine) -> ?nif_stub.
engine_get_id_nif(_Engine) -> ?nif_stub.
engine_get_name_nif(_Engine) -> ?nif_stub.
engine_get_all_methods_nif() -> ?nif_stub.

%%--------------------------------------------------------------------
%% Engine internals
engine_nif_wrapper(ok) ->
    ok;
engine_nif_wrapper(notsup) ->
    erlang:error(notsup);
engine_nif_wrapper({error, Error}) ->
    throw({error, Error}).

ensure_bin_chardata(CharData) when is_binary(CharData) ->
    CharData;
ensure_bin_chardata(CharData) ->
    unicode:characters_to_binary(CharData).

ensure_bin_cmds(CMDs) ->
    ensure_bin_cmds(CMDs, []).

ensure_bin_cmds([], Acc) ->
    lists:reverse(Acc);
ensure_bin_cmds([{Key, Value} |CMDs], Acc) ->
    ensure_bin_cmds(CMDs, [{ensure_bin_chardata(Key), ensure_bin_chardata(Value)} | Acc]);
ensure_bin_cmds([Key | CMDs], Acc) ->
    ensure_bin_cmds(CMDs, [{ensure_bin_chardata(Key), <<"">>} | Acc]).

engine_methods_convert_to_bitmask([], BitMask) ->
    BitMask;
engine_methods_convert_to_bitmask(engine_method_all, _BitMask) ->
    16#FFFF;
engine_methods_convert_to_bitmask(engine_method_none, _BitMask) ->
    16#0000;
engine_methods_convert_to_bitmask([M |Ms], BitMask) ->
    engine_methods_convert_to_bitmask(Ms, BitMask bor engine_method_atom_to_int(M)).

bool_to_int(true) -> 1;
bool_to_int(false) -> 0.

engine_method_atom_to_int(engine_method_rsa) -> 16#0001;
engine_method_atom_to_int(engine_method_dsa) -> 16#0002;
engine_method_atom_to_int(engine_method_dh) -> 16#0004;
engine_method_atom_to_int(engine_method_rand) -> 16#0008;
engine_method_atom_to_int(engine_method_ecdh) -> 16#0010;
engine_method_atom_to_int(engine_method_ecdsa) -> 16#0020;
engine_method_atom_to_int(engine_method_ciphers) -> 16#0040;
engine_method_atom_to_int(engine_method_digests) -> 16#0080;
engine_method_atom_to_int(engine_method_store) -> 16#0100;
engine_method_atom_to_int(engine_method_pkey_meths) -> 16#0200;
engine_method_atom_to_int(engine_method_pkey_asn1_meths) -> 16#0400;
engine_method_atom_to_int(engine_method_ec) -> 16#0800;
engine_method_atom_to_int(X) ->
    erlang:error(badarg, [X]).

get_test_engine() ->
    Type = erlang:system_info(system_architecture),
    LibDir = filename:join([code:priv_dir(crypto), "lib"]),
    ArchDir = filename:join([LibDir, Type]),
    case filelib:is_dir(ArchDir) of
	true  -> check_otp_test_engine(ArchDir);
	false -> check_otp_test_engine(LibDir)
    end.

check_otp_test_engine(LibDir) ->
    case filelib:wildcard("otp_test_engine*", LibDir) of
        [] ->
            {error, notexist};
        [LibName] ->
            LibPath = filename:join(LibDir,LibName),
            case filelib:is_file(LibPath) of
                true ->
                    {ok, unicode:characters_to_binary(LibPath)};
                false ->
                    {error, notexist}
            end
    end.
