use strict;
use warnings;
use utf8;
use Amon2::Lite;
use HTTP::Tiny;
use HTTP::Body;

my $REQUEST_TOKEN_URL = 'https://getpocket.com/v3/oauth/request';
my $USER_AUTHORIZATION_URL = 'https://getpocket.com/auth/authorize';
my $ACCESS_TOKEN_URL = 'https://getpocket.com/v3/oauth/authorize';
my $REDIRECT_URI = 'http://localhost:5000/access_token';

get '/' => sub {
    my $c = shift;
    return $c->render('index.tt');
};

post '/consumer_key' => sub {
    my $c = shift;

    my $consumer_key = $c->req->param("consumer_key");
    unless( $consumer_key ) {
        return $c->render('error.tt', {
            error => "consumer_keyが入力されていません"
        });
    }

    my $response = HTTP::Tiny->new->post_form( $REQUEST_TOKEN_URL, {
        consumer_key => $consumer_key,
        redirect_uri => $REDIRECT_URI,
    });
    unless( $response->{success} ) {
        return $c->render('error.tt', {
            error => "$response->{headers}->{status}: $response->{headers}->{'x-error'}",
        });
    }

    my $body = HTTP::Body->new(
        $response->{headers}->{'content-type'},
        $response->{headers}->{'content-length'},
    );
    $body->add($response->{content});
    my $request_token = $body->param->{'code'};

    $c->session->set('consumer_key' => $consumer_key);
    $c->session->set('request_token' => $request_token);

    return $c->redirect( $USER_AUTHORIZATION_URL, {
        request_token => $request_token,
        redirect_uri => $REDIRECT_URI,
    });
};

get '/access_token' => sub {
    my $c = shift;

    my $consumer_key = $c->session->get('consumer_key');
    my $request_token = $c->session->get('request_token');

    my $response = HTTP::Tiny->new->post_form( $ACCESS_TOKEN_URL, {
        consumer_key => $consumer_key,
        code => $request_token,
    });
    unless ( $response->{success} ) {
        return $c->render('error.tt', {
            error => "$response->{headers}->{status}: $response->{headers}->{'x-error'}",
        });
    }

    my $body = HTTP::Body->new(
        $response->{headers}->{'content-type'},
        $response->{headers}->{'content-length'},
    );
    $body->add($response->{content});

    return $c->render('access_token.tt', {
        access_token => $body->param->{'access_token'},
        username => $body->param->{'username'},
    });
};

# load plugins
__PACKAGE__->enable_session();
__PACKAGE__->to_app(handle_static => 1);

__DATA__

@@ index.tt
<!doctype html>
<html<head>
<head>
    <meta charset="utf-8">
    <title>PocketKey</title>
    <link rel="stylesheet" href="[% uri_for('/static/css/main.css') %]">
</head>
<body>
    <header><h1>PocketKey</h1></header>
    <form action="/consumer_key" method="post">
        consumer_key: <input type="text" size="50" maxlength="30" name="consumer_key">
        <input type="submit" value="send">
    </form>
    <a href="http://getpocket.com/developer/" target="_blank">consumer_keyを取得</a>
</body>
</html>

@@ access_token.tt
<!doctype html>
<html<head>
<head>
    <meta charset="utf-8">
    <title>PocketKey</title>
    <link rel="stylesheet" href="[% uri_for('/static/css/main.css') %]">
</head>
<body>
    <header><h1>PocketKey</h1></header>
    username: <strong>[% username %]</strong></br>
    access_token: <strong>[% access_token %]</strong><br>
    <a href="[% uri_for('/') %]">topへ戻る</a>
</body>
</html>

@@ error.tt
<!doctype html>
<html<head>
<head>
    <meta charset="utf-8">
    <title>PocketKey</title>
    <link rel="stylesheet" href="[% uri_for('/static/css/main.css') %]">
</head>
<body>
    <header><h1>PocketKey</h1></header>
    error: <strong>[% error %]</strong><br>
    <a href="[% uri_for('/') %]">topへ戻る</a>
</body>
</html>

@@ /static/css/main.css
footer {
    text-align: right;
}

