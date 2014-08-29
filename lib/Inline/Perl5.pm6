module Inline::Perl5;

use NativeCall;

my Str $p5helper;
BEGIN {
    $p5helper = IO::Path.new($?FILE).directory ~ '/p5helper.so';
}

class Perl5Object { ... }

class X::Inline::Perl5::Unmarshallable is Exception {
    has Mu $.object;
    method message() {
        "Don't know how to pass object of type {$.object.^name} to Perl 5 code";
    }
}

class PerlInterpreter is repr('CPointer') {
    sub p5_SvIOK(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns Int { * }
    sub p5_SvPOK(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns Int { * }
    sub p5_is_array(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns Int { * }
    sub p5_is_hash(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns Int { * }
    sub p5_is_undef(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns Int { * }
    sub p5_sv_to_char_star(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns Str { * }
    sub p5_sv_to_av(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_sv_to_hv(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_int_to_sv(PerlInterpreter, Int)
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_str_to_sv(PerlInterpreter, Str)
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_av_top_index(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns Int { * }
    sub p5_av_fetch(PerlInterpreter, OpaquePointer, Int)
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_av_push(PerlInterpreter, OpaquePointer, OpaquePointer)
        is native($p5helper)
        { * }
    sub p5_hv_iterinit(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns Int { * }
    sub p5_hv_iternext(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_hv_iterkeysv(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_hv_iterval(PerlInterpreter, OpaquePointer, OpaquePointer)
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_undef(PerlInterpreter)
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_newHV(PerlInterpreter)
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_newAV(PerlInterpreter)
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_newRV_noinc(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_hv_store_ent(PerlInterpreter, OpaquePointer, OpaquePointer, OpaquePointer)
        is native($p5helper)
        { * }
    sub p5_call_function(PerlInterpreter, Str, Int, CArray[OpaquePointer])
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_destruct_perl(PerlInterpreter)
        is native($p5helper)
        { * }
    sub p5_sv_iv(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns Int { * }
    sub p5_is_object(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns Int { * }
    sub p5_eval_pv(PerlInterpreter, Str, Int)
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_wrap_p6_object(PerlInterpreter, &unwrap(), &call_method(Str, OpaquePointer))
        is native($p5helper)
        returns OpaquePointer { * }
    sub p5_is_wrapped_p6_object(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        returns Int { * }
    sub p5_unwrap_p6_object(PerlInterpreter, OpaquePointer)
        is native($p5helper)
        { * }

    multi method p6_to_p5(Int:D $value) returns OpaquePointer {
        return p5_int_to_sv(self, $value);
    }
    multi method p6_to_p5(Str:D $value) returns OpaquePointer {
        return p5_str_to_sv(self, $value);
    }
    multi method p6_to_p5(OpaquePointer $value) returns OpaquePointer {
        return $value;
    }
    multi method p6_to_p5(Any:U $value) returns OpaquePointer {
        return p5_undef(self);
    }
    my $unwrapped;
    multi method p6_to_p5(Any:D $value) {
        return p5_wrap_p6_object(
            self,
            -> {
                $unwrapped = $value
            },
            -> $name, $args {
                $value."$name"(|self!p5_array_to_p6_array($args));
                CATCH { default { note $_; } }
            },
        );
        X::Inline::Perl5::Unmarshallable.new(
            :object($value),
        ).throw;
    }
    multi method p6_to_p5(Hash:D $value) returns OpaquePointer {
        my $hv = p5_newHV(self);
        for %$value -> $item {
            my $key = p5_str_to_sv(self, $item.key);
            my $value = self.p6_to_p5($item.value);
            p5_hv_store_ent(self, $hv, $key, $value);
        }
        return p5_newRV_noinc(self, $hv);
    }
    multi method p6_to_p5(Positional:D $value) returns OpaquePointer {
        my $av = p5_newAV(self);
        for @$value -> $item {
            p5_av_push(self, $av, self.p6_to_p5($item));
        }
        return p5_newRV_noinc(self, $av);
    }

    method !p5_array_to_p6_array(OpaquePointer $sv) {
        my $av = p5_sv_to_av(self, $sv);
        my $av_len = p5_av_top_index(self, $av);

        my $arr = [];
        loop (my $i = 0; $i <= $av_len; $i++) {
            $arr.push(self.p5_to_p6(p5_av_fetch(self, $av, $i)));
        }
        return $arr;
    }
    method !p5_hash_to_p6_hash(OpaquePointer $sv) {
        my OpaquePointer $hv = p5_sv_to_hv(self, $sv);

        my Int $len = p5_hv_iterinit(self, $hv);

        my $hash = {};

        for 0 .. $len - 1 {
            my OpaquePointer $next = p5_hv_iternext(self, $hv);
            my OpaquePointer $key = p5_hv_iterkeysv(self, $next);
            die 'Hash entry without key!?' unless $key;
            my Str $p6_key = p5_sv_to_char_star(self, $key);
            my $val = self.p5_to_p6(p5_hv_iterval(self, $hv, $next));
            $hash{$p6_key} = $val;
        }

        return $hash;
    }

    method p5_to_p6(OpaquePointer $value) {
        if p5_is_object(self, $value) {
            if p5_is_wrapped_p6_object(self, $value) {
                p5_unwrap_p6_object(self, $value);
                return $unwrapped;
            }
            else {
                return Perl5Object.new(perl5 => self, ptr => $value);
            }
        }
        elsif p5_SvIOK(self, $value) {
            return p5_sv_iv(self, $value);
        }
        elsif p5_SvPOK(self, $value) {
            return p5_sv_to_char_star(self, $value);
        }
        elsif p5_is_array(self, $value) {
            return self!p5_array_to_p6_array($value);
        }
        elsif p5_is_hash(self, $value) {
            return self!p5_hash_to_p6_hash($value);
        }
        elsif p5_is_undef(self, $value) {
            return Any;
        }
        die "Unsupported type $value in p5_to_p6";
    }

    method run($perl) {
        my $res = p5_eval_pv(self, $perl, 1);
        return self.p5_to_p6($res);
    }

    method call(Str $function, *@args) {
        my $len = @args.elems;
        my @svs := CArray[OpaquePointer].new();
        loop (my $i = 0; $i < $len; $i++) {
            @svs[$i] = self.p6_to_p5(@args[$i]);
        }

        my $av = p5_call_function(self, $function, $len, @svs);
        my $av_len = p5_av_top_index(self, $av);
        return
            if $av_len == -1;
        return self.p5_to_p6(p5_av_fetch(self, $av, 0))
            if $av_len == 0;

        my @retvals;
        loop ($i = 0; $i <= $av_len; $i++) {
            @retvals.push(self.p5_to_p6(p5_av_fetch(self, $av, $i)));
        }
        return @retvals;
    }

    method init_callbacks {
        self.run(q[
            package Perl6::Object;

            our $AUTOLOAD;
            sub AUTOLOAD {
                my ($self) = @_;
                my $name = $AUTOLOAD =~ s/.*:://r;
                Perl6::Object::call_method($name, @_);
            }
        ]);
    }

    submethod DESTROY {
        p5_destruct_perl(self);
    }
}

class Perl5Object {
    has OpaquePointer $.ptr;
    has PerlInterpreter $.perl5;

    Perl5Object.^add_fallback(-> $, $ { True },
        method ($name ) {
            -> \self, |args {
                $.perl5.call($name, $.ptr, args.list);
            }
        }
    );

    method sink() { self }
}

sub p5_init_perl() is export is native($p5helper) returns PerlInterpreter { * }
