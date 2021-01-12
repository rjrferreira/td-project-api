# td-project-api
td-project-api

## To run locally

### Prerequisites

Install ruby 2.5.1 and Rails 6.1.1 

### Start locally

```
$ bundle install
$ rails s
```

### Call the api

```
$ curl -d '["+4439877"]' "http://localhost:3000/aggregate"
```

## Heroku

Project is available on "https://td-project-rodrigo.herokuapp.com/"

### Call the api

```
$ curl -d '["+4439877"]' "https://td-project-rodrigo.herokuapp.com/aggregate"
```
