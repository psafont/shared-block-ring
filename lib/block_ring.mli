(*
 * Copyright (C) 2013 Citrix Systems Inc
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

module Producer(B: S.BLOCK): sig
  type t

  val create: B.t -> Cstruct.t -> [ `Ok of t | `Error of string ] Lwt.t
  val push: t -> Cstruct.t -> [ `Ok of unit | `TooBig | `Retry | `Error of string ] Lwt.t
end

module Consumer(B: S.BLOCK): sig
  type t

  val create: B.t -> Cstruct.t -> [ `Ok of t | `Error of string ] Lwt.t
  val pop: t -> [ `Ok of Cstruct.t | `Retry | `Error of string ] Lwt.t
end
